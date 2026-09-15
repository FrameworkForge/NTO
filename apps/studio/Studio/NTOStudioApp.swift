import AppKit
import NTOFoundation
import SwiftUI

@main struct NTOStudioApp: App {
  @State private var workspace: WorkspaceState
  private let store: ProjectStore?
  private let library: LibraryController?
  private let startupError: String?
  init() {
    // QA affordance: NTO_STUDIO_MODE=Library|Cull|Edit|Publish opens in that mode (used with NTO_STUDIO_LIBRARY_PATH).
    let initial = WorkspaceState()
    if let mode = ProcessInfo.processInfo.environment["NTO_STUDIO_MODE"].flatMap(StudioMode.init(rawValue:)) { initial.mode = mode }
    if ProcessInfo.processInfo.environment["NTO_STUDIO_FOCUS"] == "1" { initial.toggleFocus() }
    _workspace = State(initialValue: initial)
    do {
      let override = ProcessInfo.processInfo.environment["NTO_STUDIO_LIBRARY_PATH"]
      let locations = try override.map { LibraryLocations(root: URL(fileURLWithPath: $0, isDirectory: true)) } ?? LibraryLocations.standard()
      try FileManager.default.createDirectory(at: locations.root, withIntermediateDirectories: true)
      let opened = try ProjectStore(container: ProjectStore.container(url: locations.root.appendingPathComponent("Library.store")))
      store = opened
      library = LibraryController(store: opened, locations: locations)
      startupError = nil
    } catch {
      store = nil
      library = nil
      startupError = error.localizedDescription
    }
  }
  var body: some Scene {
    Window("NTO Studio", id: "workspace") {
      if let store, let library {
        WorkspaceView(workspace: workspace, store: store, library: library)
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
        Button("Import Photographs…") { workspace.importRequested.toggle() }
          .keyboardShortcut("i", modifiers: [.command, .shift])
          .disabled(library?.isImporting != false)
        Button("Export…") { workspace.exportRequested.toggle() }
          .keyboardShortcut("e", modifiers: [.command, .shift])
          .disabled(library?.exporter.isRunning != false)
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo") {
          if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.undoManager?.undo() }
          else { library?.editor.undo() }
        }.keyboardShortcut("z", modifiers: .command)
          .disabled((NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager?.canUndo != true && (library?.editor.isActive != true || library?.editor.history?.undo.isEmpty != false))
        Button("Redo") {
          if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.undoManager?.redo() }
          else { library?.editor.redo() }
        }.keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled((NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager?.canRedo != true && (library?.editor.isActive != true || library?.editor.history?.redo.isEmpty != false))
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
