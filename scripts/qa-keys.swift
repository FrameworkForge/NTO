// Activates NTO Studio and posts key events: each argument is "keycode[:cmd|shift|opt|ctrl,...]" or "sleep:ms".
import AppKit
import CoreGraphics
import Foundation
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "motion.nto.studio").first else {
  print("NTOStudio is not running"); exit(1)
}
app.activate(options: [.activateAllWindows])
usleep(600_000)
print("frontmost:", NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")
let source = CGEventSource(stateID: .hidSystemState)
for argument in CommandLine.arguments.dropFirst() {
  if argument.hasPrefix("sleep:") { usleep(UInt32(Int(argument.dropFirst(6)) ?? 200) * 1000); continue }
  let parts = argument.split(separator: ":")
  guard let code = UInt16(parts[0]) else { continue }
  var flags: CGEventFlags = []
  if parts.count > 1 {
    for m in parts[1].split(separator: ",") {
      switch m { case "cmd": flags.insert(.maskCommand); case "shift": flags.insert(.maskShift)
      case "opt": flags.insert(.maskAlternate); case "ctrl": flags.insert(.maskControl); default: break }
    }
  }
  for down in [true, false] {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(60_000)
  }
  usleep(250_000)
}
print("posted", CommandLine.arguments.count - 1, "steps")
