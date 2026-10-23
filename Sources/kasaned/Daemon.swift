import Foundation
import IOKit
import KasaneCore

/// Wires the hardware to KasaneCore: feeds key events and ticks to the triggers, keeps the
/// safety conditions current, and applies the Blocker's effects to the built-in keyboard.
@MainActor
final class Daemon {
    /// How often the console state is read and hold triggers are checked.
    private static let tickInterval: CFTimeInterval = 0.2

    private let config: Config
    private let registryRoot: io_registry_entry_t
    private var safety: Safety
    private var blocker: Blocker
    private var onTriggers: [TriggerRecognizer]
    private var offTriggers: [TriggerRecognizer]
    private var builtIn: BuiltInKeyboard?
    private var keyboards: KeyboardMonitor?
    private var power: PowerMonitor?

    init(config: Config) {
        self.config = config
        registryRoot = IORegistryGetRootEntry(kIOMainPortDefault)
        let console = readConsoleState(registryRoot)
        safety = Safety(
            externalKeyboardConnected: false, screenLocked: console.screenLocked, onConsole: console.onConsole,
            asleep: false)
        blocker = Blocker(safety: safety)
        onTriggers = config.on.map(TriggerRecognizer.init)
        offTriggers = config.off.map(TriggerRecognizer.init)
    }

    func start() throws(IOKitError) {
        log("starting OFF; \(describe(safety))")
        keyboards = KeyboardMonitor(config: config, delegate: self)
        power = try PowerMonitor(delegate: self)
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + Self.tickInterval, Self.tickInterval, 0, 0
        ) { [unowned self] _ in
            MainActor.assumeIsolated { self.tick() }
        }
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .defaultMode)
    }

    /// Turns OFF before exiting, so the LED does not stay lit after kasaned stops.
    func stop() {
        transition("stopping") { $0.offTrigger() }
        log("stopped")
        exit(EXIT_SUCCESS)
    }

    private func tick() {
        let console = readConsoleState(registryRoot)
        updateSafety {
            $0.onConsole = console.onConsole
            $0.screenLocked = console.screenLocked
        }
        let now = uptime()
        react(
            onFired: Self.anyFired(&onTriggers) { $0.advance(to: now) },
            offFired: Self.anyFired(&offTriggers) { $0.advance(to: now) })
    }

    private func react(onFired: Bool, offFired: Bool) {
        if offFired {
            transition("OFF trigger") { $0.offTrigger() }
        }
        if onFired {
            if !blocker.isOn && !safety.permitsBlocking {
                log("ON trigger refused; \(describe(safety))")
            }
            transition("ON trigger") { $0.onTrigger() }
        }
    }

    private func updateSafety(_ change: (inout Safety) -> Void) {
        var next = safety
        change(&next)
        guard next != safety else { return }
        safety = next
        log(describe(next))
        transition("a safety condition no longer holds") { $0.update(next) }
    }

    private func transition(_ reason: String, _ change: (inout Blocker) -> [Effect]) {
        let wasOn = blocker.isOn
        apply(change(&blocker))
        if blocker.isOn != wasOn {
            log("\(blocker.isOn ? "ON" : "OFF"): \(reason)")
        }
    }

    private func apply(_ effects: [Effect]) {
        for effect in effects {
            switch effect {
            case .seize:
                guard let builtIn else {
                    log("cannot seize: there is no built-in keyboard")
                    blocker.lostSeize()
                    return
                }
                do {
                    try builtIn.seize()
                } catch {
                    log("\(error)")
                    blocker.lostSeize()
                    return
                }
            case .release:
                guard let builtIn else { preconditionFailure("release without a built-in keyboard") }
                do {
                    try builtIn.release()
                } catch {
                    // Exiting makes the kernel end the seize that release failed to end.
                    log("\(error); exiting")
                    exit(EXIT_FAILURE)
                }
            case .ledOn, .ledOff:
                guard let builtIn else { preconditionFailure("LED change without a built-in keyboard") }
                do {
                    try builtIn.setCapsLockLED(effect == .ledOn)
                } catch {
                    log("\(error)")
                }
            }
        }
    }

    /// Steps every recognizer, so each keeps its own progress, and reports whether any fired.
    private static func anyFired(
        _ recognizers: inout [TriggerRecognizer], _ step: (inout TriggerRecognizer) -> Bool
    ) -> Bool {
        var fired = false
        for index in recognizers.indices where step(&recognizers[index]) {
            fired = true
        }
        return fired
    }

    private func describe(_ safety: Safety) -> String {
        "external keyboard \(safety.externalKeyboardConnected ? "connected" : "absent"), "
            + "screen \(safety.screenLocked ? "locked" : "unlocked"), "
            + "\(safety.onConsole ? "on" : "off") console, \(safety.asleep ? "asleep" : "awake")"
    }
}

extension Daemon: KeyboardMonitorDelegate {
    func builtInKeyboardAppeared(_ device: IOHIDDevice) {
        do {
            let keyboard = try BuiltInKeyboard(device: device)
            // A previous run may have exited while ON and left the LED lit.
            try keyboard.setCapsLockLED(false)
            builtIn = keyboard
        } catch {
            log("\(error); exiting")
            exit(EXIT_FAILURE)
        }
    }

    func builtInKeyboardDisappeared() {
        builtIn = nil
        let wasOn = blocker.isOn
        blocker.lostSeize()
        log(wasOn ? "OFF: the built-in keyboard disappeared" : "the built-in keyboard disappeared")
    }

    func externalKeyboardCountChanged(_ count: Int) {
        updateSafety { $0.externalKeyboardConnected = count > 0 }
    }

    func keyEvent(_ event: KeyEvent) {
        react(
            onFired: Self.anyFired(&onTriggers) { $0.handle(event) },
            offFired: Self.anyFired(&offTriggers) { $0.handle(event) })
    }
}

extension Daemon: PowerMonitorDelegate {
    func systemWillSleep() {
        updateSafety { $0.asleep = true }
    }

    func systemDidWake() {
        updateSafety { $0.asleep = false }
    }
}
