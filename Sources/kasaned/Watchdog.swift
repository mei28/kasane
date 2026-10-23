import Darwin
import Dispatch
import Synchronization

/// Ends kasaned when its main thread stops while the built-in keyboard is seized. A stopped main
/// thread no longer notices the screen lock, and while seized not even Touch ID unlocks the lock
/// screen; exiting makes the kernel end the seize.
///
/// @unchecked: the timer is only touched in init; the shared state is atomic.
final class Watchdog: @unchecked Sendable {
    private static let limit: UInt64 = 2_000_000_000  // nanoseconds

    private let lastBeat = Atomic<UInt64>(0)
    private let armed = Atomic<Bool>(false)
    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "dev.mei.kasane.watchdog"))

    init() {
        timer.setEventHandler { [unowned self] in check() }
        timer.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
        timer.resume()
    }

    /// Called from the main thread's tick.
    func beat() {
        lastBeat.store(clock_gettime_nsec_np(CLOCK_UPTIME_RAW), ordering: .relaxed)
    }

    /// Armed only while the built-in keyboard is seized.
    func arm(_ seized: Bool) {
        beat()
        armed.store(seized, ordering: .relaxed)
    }

    private func check() {
        guard armed.load(ordering: .relaxed) else { return }
        let silent = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - lastBeat.load(ordering: .relaxed)
        guard silent > Self.limit else { return }
        log("the main thread has been stuck for \(silent / 1_000_000) ms while seized; exiting to release the keyboard")
        _exit(EXIT_FAILURE)
    }
}
