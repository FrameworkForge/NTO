import NTOFoundation
import SwiftUI

@main struct NTOStudioApp: App {
  @State private var workspace = WorkspaceState()
  private let store: ProjectStore?
  private let startupError: String?
  init() {
    do {
      store = try ProjectStore(container: ProjectStore.container())
      startupError = nil
    } catch {
      store = nil
      startupError = error.localizedDescription
    }
  }
  var body: some Scene {
    WindowGroup {
      if let store {
        WorkspaceView(workspace: workspace, store: store)
      } else {
        ContentUnavailableView(
          "Library could not open", systemImage: "externaldrive.badge.exclamationmark",
          description: Text(
            startupError ?? "Restart Studio to try again. Your source files have not been changed.")
        )
      }
    }
    .defaultSize(width: 1200, height: 800)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Project") { workspace.newProjectRequested.toggle() }.keyboardShortcut(
          "n", modifiers: .command)
      }
      CommandMenu("Workspace") {
        ForEach(Array(StudioMode.allCases.enumerated()), id: \.element.id) { i, mode in
          Button(mode.rawValue) { workspace.mode = mode }.keyboardShortcut(
            KeyEquivalent(Character(String(i + 1))), modifiers: .command)
        }
        Divider()
        Button(workspace.isFocused ? "Leave Focus Mode" : "Enter Focus Mode") {
          workspace.toggleFocus()
        }.keyboardShortcut(.tab, modifiers: [])
        Button("Toggle Sidebar") { workspace.sidebarVisible.toggle() }.keyboardShortcut(
          "s", modifiers: [.command, .control]
        ).disabled(workspace.isFocused)
        Button("Toggle Inspector") { workspace.inspectorVisible.toggle() }.keyboardShortcut(
          "i", modifiers: [.command, .option]
        ).disabled(workspace.isFocused)
      }
    }
  }
}
