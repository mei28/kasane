/// Which of the config's trigger lists completed a gesture on one step.
public struct Fired: Equatable, Sendable {
    public var on: Bool
    public var off: Bool

    public init(on: Bool, off: Bool) {
        self.on = on
        self.off = off
    }
}

/// The recognizers for every ON and OFF trigger in a config. Each step goes to every
/// recognizer, so each keeps its own progress.
public struct TriggerSet: Sendable {
    private let config: Config
    private var on: [TriggerRecognizer]
    private var off: [TriggerRecognizer]

    public init(_ config: Config) {
        self.config = config
        on = config.on.map(TriggerRecognizer.init)
        off = config.off.map(TriggerRecognizer.init)
    }

    /// Forgets every gesture in progress. kasaned calls it whenever it turns ON or OFF, so taps
    /// from before the switch cannot complete a gesture after it.
    public mutating func reset() {
        self = TriggerSet(config)
    }

    public mutating func handle(_ event: KeyEvent) -> Fired {
        Fired(on: Self.anyFired(&on) { $0.handle(event) }, off: Self.anyFired(&off) { $0.handle(event) })
    }

    public mutating func advance(to time: Duration) -> Fired {
        Fired(on: Self.anyFired(&on) { $0.advance(to: time) }, off: Self.anyFired(&off) { $0.advance(to: time) })
    }

    private static func anyFired(
        _ recognizers: inout [TriggerRecognizer], _ step: (inout TriggerRecognizer) -> Bool
    ) -> Bool {
        var fired = false
        for index in recognizers.indices where step(&recognizers[index]) {
            fired = true
        }
        return fired
    }
}
