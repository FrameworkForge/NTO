import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Presets, copy/paste and selection sync as inspector sections. Choosing a preset applies it as one undo step.
struct EditPresetsSection: View {
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
    Section {
      LabeledContent("Preset") {
        Menu {
          if presets.presets.isEmpty { Text("No presets saved yet") }
          ForEach(presets.presets) { preset in
            Button(preset.name) { editor.apply(preset.adjustments) }
              .help(preset.parameters.map(\.title).sorted().joined(separator: ", "))
          }
          Divider()
          Button("Save Preset…") { savingPreset = true }.disabled(editor.history == nil)
          if !presets.presets.isEmpty {
            Menu("Manage") {
              ForEach(presets.presets) { preset in
                Menu(preset.name) {
                  Button("Rename…") { renaming = preset; renameText = preset.name }
                  Button("Export…") { exportPreset(preset) }
                  Divider()
                  Button("Delete", role: .destructive) { attempt { try presets.delete(preset.id) } }
                }
              }
            }
          }
          Button("Import Preset…") { importPreset() }
          Button("Show Presets Folder") { NSWorkspace.shared.activateFileViewerSelecting([presets.directory]) }
        } label: { Text("Choose") }
          .fixedSize().accessibilityLabel("Presets")
      }
      LabeledContent("Edits") {
        HStack(spacing: 6) {
          Button("Copy…") { copying = true }.disabled(editor.history == nil)
          Button("Paste") { editor.paste() }.disabled(editor.copied == nil || editor.history == nil)
        }.controlSize(.small)
      }
      LabeledContent("Sync") {
        VStack(alignment: .trailing, spacing: 4) {
          HStack(spacing: 6) {
            Button("To \(library.actionableIDs.count) Selected") { library.syncEdits(editor.copied ?? [:], to: library.actionableIDs) }
              .disabled(editor.copied == nil || library.actionableIDs.isEmpty || batch.isRunning)
              .help("Applies the copied parameters to every selected photograph. Each one gets its own undo step.")
            Button("Revert") { library.revertLastSync() }.disabled(batch.lastOutcomes.isEmpty || batch.isRunning)
          }.controlSize(.small)
          if batch.isRunning {
            HStack(spacing: 6) {
              ProgressView(value: Double(batch.completed), total: Double(max(batch.total, 1))).frame(width: 80)
              Text("\(batch.completed)/\(batch.total)").font(.caption).monospacedDigit()
              Button("Stop") { batch.cancel() }.controlSize(.mini)
            }
          } else if let summary = batch.summary {
            Text(summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
          }
        }
      }
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
      if !presets.issues.isEmpty {
        Text("Some preset files could not be read: \(presets.issues.joined(separator: "; "))").font(.caption).foregroundStyle(.secondary)
      }
      if !batch.failures.isEmpty {
        Text(batch.failures.prefix(3).joined(separator: "; ")).font(.caption).foregroundStyle(.secondary)
      }
    } header: { Text("Presets") }
    .sheet(isPresented: $savingPreset) {
      ParameterSelectionSheet(title: "Save Preset", confirmTitle: "Save", askName: true) { name, parameters in
        attempt {
          guard let recipe = editor.history?.current else { return }
          try presets.save(EditPreset(name: name, adjustments: recipe.adjustments(for: parameters)))
        }
      }
    }
    .sheet(isPresented: $copying) {
      ParameterSelectionSheet(title: "Copy Edits", confirmTitle: "Copy", askName: false) { _, parameters in
        editor.copy(parameters)
      }
    }
    .sheet(item: $renaming) { preset in
      VStack(alignment: .leading, spacing: 14) {
        Text("Rename Preset").font(.headline)
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
