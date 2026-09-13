import AppKit
let icon = NSImage(contentsOfFile:CommandLine.arguments[1])!
for path in CommandLine.arguments.dropFirst(2) {
    guard NSWorkspace.shared.setIcon(icon,forFile:path,options:[]) else { fatalError("Could not set icon for \(path)") }
    print("Applied icon: \(path)")
}
