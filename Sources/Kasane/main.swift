import AppKit

// An AppKit entry point rather than a SwiftUI App: Kasane is a menu bar app (LSUIElement) whose
// only window is opened from the menu.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
