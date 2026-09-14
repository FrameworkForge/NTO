import AppKit
import SwiftUI

/// Window-scoped routing survives replacement of the fit image with a pixel-inspection scroll view.
/// The representable owns its monitor; sheets, text editors and modified system shortcuts bypass it.
struct CullKeyboardShortcuts: NSViewRepresentable {
  let handle: (NSEvent) -> Bool
  func makeNSView(context: Context) -> KeyView { let view = KeyView(); view.handle = handle; return view }
  func updateNSView(_ view: KeyView, context: Context) { view.handle = handle }
  static func dismantleNSView(_ view: KeyView, coordinator: ()) { view.stop() }
  final class KeyView: NSView {
    var handle: ((NSEvent) -> Bool)?
    private var monitor: Any?
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow(); stop()
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, let window = self.window, window.isKeyWindow, event.window === window,
          window.attachedSheet == nil, !(window.firstResponder is NSTextView),
          event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
        return self.handle?(event) == true ? nil : event
      }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
  }
}
