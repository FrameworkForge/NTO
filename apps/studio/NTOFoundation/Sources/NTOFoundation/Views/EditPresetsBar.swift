import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Presets, copy/paste and selection sync for Edit mode. Hovering a preset previews it; clicking applies it as one undo step.
struct EditPresetsBar: View {
  let library: LibraryController
  private var editor: EditController { library.editor }
  private var presets: PresetStore { library.presets }
  private var batch: BatchEditController { library.batch }
  @State private var savingPreset = false
  @State private var copying = false
  @State private var renaming: EditPreset?
  @State private var renameText = ""
  @State private var error: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text("Presets").font(.headline)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            if presets.presets.isEmpty { Text("None saved yet").font(.caption).foregroundStyle(.secondary) }
            ForEach(presets.presets) { preset in
              Button(preset.name) { editor.apply(preset.adjustments) }
                .controlSize(.small).disabled(editor.history == nil)
                .help(preset.parameters.map(\.title).sorted().joined(separator: ", "))
                .onHover { hovering in
                  if hovering { editor.previewAdjustments(preset.adjustments) } else { editor.clearAdjustmentPreview() }
                }
                .contextMenu {
                  Button("Rename…") { renaming = preset; renameText = preset.name }
                  Button("Export…") { exportPreset(preset) }
                  Divider()
                  Button("Delete preset", role: .destructive) { attempt { try presets.delete(preset.id) } }
                }
            }
          }
        }
        Button("Save preset…") { savingPreset = true }.controlSize(.small).disabled(editor.history == nil)
        Menu {
          Button("Import preset…") { importPreset() }
          Button("Show Presets folder") { NSWorkspace.shared.activateFileViewerSelecting([presets.directory]) }
        } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 28)
          .accessibilityLabel("More preset actions")
      }
      HStack(spacing: 8) {
        Button("Copy edits…") { copying = true }.controlSize(.small).disabled(editor.history == nil)
        Button("Paste edits") { editor.paste() }.controlSize(.small).disabled(editor.copied == nil || editor.history == nil)
        Button("Sync to \(library.actionableIDs.count) selected") { library.syncEdits(editor.copied ?? [:], to: library.actionableIDs) }
          .controlSize(.small).disabled(editor.copied == nil || library.actionableIDs.isEmpty || batch.isRunning)
          .help("Applies the copied parameters to every selected photograph. Each one gets its own undo step.")
        Button("Revert sync") { library.revertLastSync() }.controlSize(.small)
          .disabled(batch.lastOutcomes.isEmpty || batch.isRunning)
        if batch.isRunning {
          ProgressView(value: Double(batch.completed), total: Double(max(batch.total, 1))).frame(width: 90)
          Text("\(batch.completed)/\(batch.total)").font(.caption).monospacedDigit()
          Button("Stop") { batch.cancel() }.controlSize(.small)
        } else if let summary = batch.summary {
          Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer()
      }
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
      if !presets.issues.isEmpty {
        Text("Some preset files could not be read: \(presets.issues.joined(separator: "; "))").font(.caption).foregroundStyle(.secondary)
      }
      if !batch.failures.isEmpty {
        Text(batch.failures.prefix(3).joined(separator: "; ")).font(.caption).foregroundStyle(.secondary)
      }
    }
    .sheet(isPresented: $savingPreset) {
      ParameterSelectionSheet(title: "Save preset", confirmTitle: "Save", askName: true) { name, parameters in
        attempt {
          guard let recipe = editor.history?.current else { return }
          try presets.save(EditPreset(name: name, adjustments: recipe.adjustments(for: parameters)))
        }
      }
    }
    .sheet(isPresented: $copying) {
      ParameterSelectionSheet(title: "Copy edits", confirmTitle: "Copy", askName: false) { _, parameters in
        editor.copy(parameters)
      }
    }
    .sheet(item: $renaming) { preset in
      VStack(alignment: .leading, spacing: 14) {
        Text("Rename preset").font(.headline)
        TextField("Preset name", text: $renameText).textFieldStyle(.roundedBorder)
        HStack {
          Button("Cancel") { renaming = nil }.keyboardShortcut(.cancelAction)
          Spacer()
          Button("Rename") { attempt { try presets.rename(preset.id, to: renameText) }; renaming = nil }
            .keyboardShortcut(.defaultAction).disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }.padding(24).frame(width: 360)
    }
  }

  private func attempt(_ operation: () throws -> Void) {
    do { try operation(); error = nil } catch { self.error = error.localizedDescription }
  }
  private func importPreset() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = true; panel.prompt = "Import"
    guard panel.runModal() == .OK else { return }
    for url in panel.urls { attempt { try presets.importPreset(from: url) } }
  }
  private func exportPreset(_ preset: EditPreset) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = preset.name.replacingOccurrences(of: "/", with: "-") + ".json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    attempt { try presets.export(preset.id, to: url) }
  }
}

/// Chooses which parameters a preset or copy carries. White balance and geometry start unchecked on purpose.
struct ParameterSelectionSheet: View {
  let title: String
  let confirmTitle: String
  let askName: Bool
  let onConfirm: (String, Set<EditParameter>) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var selected = EditParameter.safeDefaults

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title).font(.headline)
      if askName { TextField("Preset name", text: $name).textFieldStyle(.roundedBorder) }
      HStack(alignment: .top, spacing: 20) {
        ForEach(EditGroup.allCases) { group in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(group.rawValue).font(.subheadline.weight(.semibold))
              Spacer()
              Button(groupFullySelected(group) ? "None" : "All") { toggleGroup(group) }.controlSize(.mini)
                .accessibilityLabel("\(groupFullySelected(group) ? "Deselect" : "Select") all \(group.rawValue)")
            }
            ForEach(EditParameter.parameters(in: group), id: \.self) { parameter in
              Toggle(parameter.title, isOn: Binding(
                get: { selected.contains(parameter) },
                set: { if $0 { selected.insert(parameter) } else { selected.remove(parameter) } }
              )).toggleStyle(.checkbox).font(.caption)
            }
          }.frame(minWidth: 130, alignment: .leading)
        }
      }
      Text("White balance and geometry are off by default: they belong to one photograph unless you choose to include them.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Text("\(selected.count) parameter\(selected.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
        Button(confirmTitle) { onConfirm(name, selected); dismiss() }.keyboardShortcut(.defaultAction)
          .disabled(selected.isEmpty || (askName && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
      }
    }.padding(24).frame(width: 640)
  }
  private func groupFullySelected(_ group: EditGroup) -> Bool {
    EditParameter.parameters(in: group).allSatisfy { selected.contains($0) }
  }
  private func toggleGroup(_ group: EditGroup) {
    let members = EditParameter.parameters(in: group)
    if groupFullySelected(group) { members.forEach { selected.remove($0) } } else { members.forEach { selected.insert($0) } }
  }
}
