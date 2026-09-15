import CoreGraphics
import Foundation
let name = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "NTOStudio"
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list where (window[kCGWindowOwnerName as String] as? String) == name {
  let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
  if let number = window[kCGWindowNumber as String] as? Int, (bounds["Height"] as? Double ?? 0) > 200 {
    print(number, bounds["X"] ?? 0, bounds["Y"] ?? 0, bounds["Width"] ?? 0, bounds["Height"] ?? 0)
  }
}
