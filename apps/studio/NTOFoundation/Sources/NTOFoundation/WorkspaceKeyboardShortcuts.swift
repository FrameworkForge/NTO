import AppKit
import SwiftUI

/// Routes Tab within this workspace window, including when its toolbar has focus.
/// Sheets and text editing keep their normal keyboard navigation.
public struct WorkspaceKeyboardShortcuts: NSViewRepresentable {
    private let toggleFocus: () -> Void

    public init(toggleFocus: @escaping () -> Void) { self.toggleFocus = toggleFocus }

    public func makeNSView(context: Context) -> ShortcutView {
        let view = ShortcutView()
        view.toggleFocus = toggleFocus
        return view
    }

    public func updateNSView(_ view: ShortcutView, context: Context) {
        view.toggleFocus = toggleFocus
    }

    public static func dismantleNSView(_ view: ShortcutView, coordinator: ()) {
        view.stopMonitoring()
    }

    public final class ShortcutView: NSView {
        var toggleFocus: (() -> Void)?
        private var monitor: Any?

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window,
                    event.window === window,
                    window.attachedSheet == nil,
                    !(window.firstResponder is NSTextView),
                    event.keyCode == 48,
                    event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
                else { return event }
                if !event.isARepeat { self.toggleFocus?() }
                return nil
            }
        }

        fileprivate func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
