import AppKit

// Explicit AppKit entry point. We do not use @main / @NSApplicationMain because, for a
// pure-AppKit app without Storyboards, those attributes do not reliably call
// NSApplication.shared.run() on every macOS version — the app launches but the event
// loop never starts, applicationDidFinishLaunching never fires, and no status item
// appears. Doing it by hand is the documented, future-proof path.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
