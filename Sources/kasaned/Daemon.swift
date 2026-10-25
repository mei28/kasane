import Foundation
import IOKit
import KasaneCore
import KasaneIPC
import notify

/// Wires the hardware to KasaneCore: feeds key events and ticks to the triggers, keeps the
/// safety conditions current, applies the Blocker's effects to the built-in keyboard, and
/// answers the menu bar app.
@MainActor
final class Daemon {
    /// How often the console state is read and hold triggers are checked.
    private static let tickInterval: CFTimeInterval = 0.2
    /// How often keyboards that could not be opened are tried again.
    private static let retryInterval: Duration = .seconds(5)

    private struct Recording {
        var recorder: GestureRecorder
        let owner: Int
        let reply: @Sendable (Data) -> Void
    }

    private let registryRoot: io_registry_entry_t
    private let store: ConfigStore
    private let watchdog: Watchdog
    /// nil while the config file is unusable; kasaned then runs without triggers.
    private var config: Config?
    private var configError: String?
    private var safety: Safety
    private var blocker: Blocker
    private var triggers: TriggerSet
    private var builtIn: BuiltInKeyboard?
    private var builtInState = BuiltInKeyboardState.absent
    /// The built-in keyboard while it cannot be opened, kept to try again.
    private var unopenedBuiltIn: IOHIDDevice?
    private var lastRetry = Duration.zero
    private var recording: Recording?
    private var lastPublished: Status?
    private var keyboards: KeyboardMonitor?
    private var power: PowerMonitor?
    private var xpc: XPCServer?

    init(store: ConfigStore, watchdog: Watchdog) {
        self.store = store
        self.watchdog = watchdog
        registryRoot = IORegistryGetRootEntry(kIOMainPortDefault)
        let console = readConsoleState(registryRoot)
        safety = Safety(
            externalKeyboardConnected: false, screenLocked: console.screenLocked, onConsole: console.onConsole,
            asleep: false)
        do {
            let config = try store.load()
            self.config = config
            blocker = Blocker(safety: safety, paused: config.paused)
            triggers = TriggerSet(config)
        } catch {
            // Without a usable config there are no triggers, so kasaned never blocks; the app
            // shows the error and can save a new config.
            config = nil
            configError = "\(error)"
            log("cannot use \(store.url.path): \(error)")
            blocker = Blocker(safety: safety, paused: false)
            triggers = .none
        }
    }

    func start(clientRequirement: String) throws(IOKitError) {
        log("starting OFF\(blocker.isPaused ? ", paused" : ""); \(describe(safety))")
        keyboards = KeyboardMonitor(delegate: self)
        power = try PowerMonitor(delegate: self)
        xpc = XPCServer(daemon: self, clientRequirement: clientRequirement)
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + Self.tickInterval, Self.tickInterval, 0, 0
        ) { [unowned self] _ in
            MainActor.assumeIsolated { self.tick() }
        }
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .defaultMode)
        publish()
    }

    /// Turns OFF before exiting, so the LED does not stay lit after kasaned stops.
    func stop() {
        transition("stopping") { $0.offTrigger() }
        log("stopped")
        exit(EXIT_SUCCESS)
    }

    // MARK: - Requests from the menu bar app

    func statusData() -> Data {
        encode(currentStatus)
    }

    func setBlocked(_ blocked: Bool) -> Data {
        if blocked {
            // Without a config there is no key to turn OFF again.
            if config == nil {
                log("block from the menu refused; no usable config")
            } else if recording == nil {
                if !blocker.isOn && !blocker.isPaused && !safety.permitsBlocking {
                    log("block from the menu refused; \(describe(safety))")
                }
                transition("blocked from the menu") { $0.onTrigger() }
            }
        } else {
            transition("unblocked from the menu") { $0.offTrigger() }
        }
        return statusData()
    }

    func setPaused(_ paused: Bool) -> Data {
        if paused {
            transition("paused") { $0.pause() }
        } else {
            blocker.resume()
        }
        log(paused ? "paused" : "resumed")
        // A broken config file stays as it is until the app saves a new one.
        if var config {
            config.paused = paused
            self.config = config
            do {
                try store.save(config)
            } catch {
                log("cannot save the pause: \(error)")
            }
        }
        publish()
        return statusData()
    }

    /// The config in use, or JSON null while the config file is unusable.
    func configData() -> Data {
        encode(config)
    }

    func applyConfig(_ data: Data) -> Data {
        var newConfig: Config
        do {
            newConfig = try Config.parse(data)
        } catch let error as ConfigError {
            return encode(ConfigApplyOutcome.rejected(error))
        } catch {
            return encode(ConfigApplyOutcome.unreadable("\(error)"))
        }
        // Pausing is the menu's business; a settings window opened earlier may hold a stale value.
        newConfig.paused = blocker.isPaused
        do {
            try store.save(newConfig)
        } catch {
            return encode(ConfigApplyOutcome.notSaved("\(error)"))
        }
        config = newConfig
        configError = nil
        triggers = TriggerSet(newConfig)
        log("applied a new config")
        publish()
        return encode(ConfigApplyOutcome.applied)
    }

    func record(for client: Int, reply: @escaping @Sendable (Data) -> Void) {
        guard recording == nil else {
            reply(encode(RecordingOutcome.busy))
            return
        }
        // Recording suspends every trigger, so it must not start with the keyboard seized.
        transition("recording a trigger") { $0.offTrigger() }
        recording = Recording(recorder: GestureRecorder(startedAt: uptime()), owner: client, reply: reply)
        log("recording a trigger")
        publish()
    }

    func cancelRecording(for client: Int) {
        guard recording?.owner == client else { return }
        finishRecording(.cancelled)
    }

    func connectionClosed(_ client: Int) {
        cancelRecording(for: client)
    }

    // MARK: - Ticks and events

    private func tick() {
        watchdog.beat()
        let now = uptime()
        if now - lastRetry >= Self.retryInterval {
            lastRetry = now
            retryUnopenedKeyboards()
        }
        let console = readConsoleState(registryRoot)
        updateSafety {
            $0.onConsole = console.onConsole
            $0.screenLocked = console.screenLocked
        }
        if let recording {
            if recording.recorder.isFinished(at: now) {
                switch recording.recorder.result() {
                case .success(let trigger): finishRecording(.recorded(trigger))
                case .failure(let error): finishRecording(.rejected(error))
                }
            }
            return
        }
        react(triggers.advance(to: now))
    }

    private func react(_ fired: Fired) {
        guard fired.on || fired.off else { return }
        if fired.on && !blocker.isOn && !blocker.isPaused && !safety.permitsBlocking {
            log("ON trigger refused; \(describe(safety))")
        }
        transition(blocker.isOn ? "OFF trigger" : "ON trigger") { $0.triggered(on: fired.on, off: fired.off) }
    }

    private func finishRecording(_ outcome: RecordingOutcome) {
        guard let recording else { preconditionFailure("finishing a recording that is not running") }
        self.recording = nil
        triggers.reset()
        log("recording ended: \(outcome)")
        recording.reply(encode(outcome))
        publish()
    }

    private func retryUnopenedKeyboards() {
        keyboards?.refreshRemappings()
        keyboards?.retryUnopenedExternals()
        if let unopenedBuiltIn {
            openBuiltIn(unopenedBuiltIn)
        }
    }

    // MARK: - State changes

    private func updateSafety(_ change: (inout Safety) -> Void) {
        var next = safety
        change(&next)
        guard next != safety else { return }
        safety = next
        log(describe(next))
        transition("a safety condition no longer holds") { $0.update(next) }
        publish()
    }

    private func transition(_ reason: String, _ change: (inout Blocker) -> [Effect]) {
        let wasOn = blocker.isOn
        apply(change(&blocker))
        guard blocker.isOn != wasOn else { return }
        // Taps from before the switch must not complete a gesture after it.
        triggers.reset()
        watchdog.arm(blocker.isOn)
        log("\(blocker.isOn ? "ON" : "OFF"): \(reason)")
        publish()
    }

    private func apply(_ effects: [Effect]) {
        for effect in effects {
            switch effect {
            case .seize:
                guard let builtIn else {
                    log("cannot seize: the built-in keyboard is not open")
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

    private func openBuiltIn(_ device: IOHIDDevice) {
        do {
            let keyboard = try BuiltInKeyboard(device: device)
            builtIn = keyboard
            unopenedBuiltIn = nil
            builtInState = .present
            log("built-in keyboard opened")
            do {
                // A previous run may have exited while ON and left the LED lit.
                try keyboard.setCapsLockLED(false)
            } catch {
                log("\(error)")
            }
        } catch where error.code == kIOReturnNotPermitted {
            if builtInState != .notPermitted {
                log("\(error); grant Input Monitoring to Kasane, retrying every 5 s")
            }
            unopenedBuiltIn = device
            builtInState = .notPermitted
        } catch {
            log("\(error); exiting")
            exit(EXIT_FAILURE)
        }
        publish()
    }

    // MARK: - Status

    private var currentStatus: Status {
        Status(
            isOn: blocker.isOn, isPaused: blocker.isPaused, safety: safety, builtInKeyboard: builtInState,
            configError: configError, isRecording: recording != nil)
    }

    /// Tells the app the status changed, so it asks for it again.
    private func publish() {
        let status = currentStatus
        guard status != lastPublished else { return }
        lastPublished = status
        notify_post(statusChangedNotification)
    }

    private func encode(_ value: some Encodable) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            preconditionFailure("encoding \(value) failed: \(error)")
        }
    }

    private func describe(_ safety: Safety) -> String {
        "external keyboard \(safety.externalKeyboardConnected ? "connected" : "absent"), "
            + "screen \(safety.screenLocked ? "locked" : "unlocked"), "
            + "\(safety.onConsole ? "on" : "off") console, \(safety.asleep ? "asleep" : "awake")"
    }
}

extension Daemon: KeyboardMonitorDelegate {
    func builtInKeyboardAppeared(_ device: IOHIDDevice) {
        openBuiltIn(device)
    }

    func builtInKeyboardDisappeared() {
        builtIn = nil
        unopenedBuiltIn = nil
        builtInState = .absent
        let wasOn = blocker.isOn
        blocker.lostSeize()
        watchdog.arm(false)
        log(wasOn ? "OFF: the built-in keyboard disappeared" : "the built-in keyboard disappeared")
        publish()
    }

    func externalKeyboardCountChanged(_ count: Int) {
        updateSafety { $0.externalKeyboardConnected = count > 0 }
    }

    func keyEvent(_ event: KeyEvent) {
        if recording != nil {
            recording?.recorder.record(event)
            return
        }
        react(triggers.handle(event))
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
