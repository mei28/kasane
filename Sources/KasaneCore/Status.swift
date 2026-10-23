/// Whether kasaned can use the built-in keyboard.
public enum BuiltInKeyboardState: String, Codable, Sendable {
    case present
    case absent
    /// Opening it failed, almost always because Input Monitoring is not granted.
    case notPermitted
}

/// What kasaned reports to the menu bar app.
public struct Status: Codable, Equatable, Sendable {
    public var isOn: Bool
    public var isPaused: Bool
    public var safety: Safety
    public var builtInKeyboard: BuiltInKeyboardState
    /// Why the config file could not be used; kasaned then runs with no triggers.
    public var configError: String?
    public var isRecording: Bool

    public init(
        isOn: Bool, isPaused: Bool, safety: Safety, builtInKeyboard: BuiltInKeyboardState,
        configError: String?, isRecording: Bool
    ) {
        self.isOn = isOn
        self.isPaused = isPaused
        self.safety = safety
        self.builtInKeyboard = builtInKeyboard
        self.configError = configError
        self.isRecording = isRecording
    }
}

/// How a recording requested by the menu bar app ended.
public enum RecordingOutcome: Codable, Equatable, Sendable {
    case recorded(Trigger)
    case rejected(RecordingError)
    case cancelled
    /// Another recording was already running.
    case busy
}
