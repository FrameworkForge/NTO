import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Export settings for the current selection. Settings persist between exports; the folder is chosen each time.
public struct ExportSheet: View {
  let library: LibraryController
  let projectTitle: String
  @Environment(\.dismiss) private var dismiss
  @AppStorage("exportSpecification") private var storedSpecification = ""
  @State private var specification = ExportSpecification()
  @State private var destination: URL?
  @State private var fitDimension = 2048
  @State private var error: String?
  public init(library: LibraryController, projectTitle: String) { self.library = library; self.projectTitle = projectTitle }

  private var selected: [PhotoRecord] { library.visiblePhotos.filter { library.actionableIDs.contains($0.id) } }
  private var example: String {
    guard let first = selected.first else { return "" }
    return ExportNaming.filename(template: specification.filenameTemplate, photo: first, projectTitle: projectTitle,
      index: 1, count: selected.count, format: specification.format)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Export \(selected.count) photograph\(selected.count == 1 ? "" : "s")").font(.title2)
      Text("Each file is rendered from its saved edits. Originals are never changed.").font(.callout).foregroundStyle(.secondary)
      HStack {
        Button("Choose folder…") { chooseFolder() }
        Text(destination?.path(percentEncoded: false) ?? "No folder chosen").font(.caption).lineLimit(1).truncationMode(.middle)
        Spacer()
      }
      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
        GridRow {
          Text("Format")
          Picker("Format", selection: $specification.format) {
            ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
          }.pickerStyle(.segmented).labelsHidden().frame(width: 200)
        }
        if specification.format == .jpeg {
          GridRow {
            Text("Quality")
            HStack {
              Slider(value: $specification.quality, in: 0.5...1).frame(width: 200).accessibilityLabel("JPEG quality")
              Text("\(Int((specification.quality * 100).rounded()))%").monospacedDigit().frame(width: 44, alignment: .leading)
            }
          }
        }
        GridRow {
          Text("Size")
          HStack {
            Picker("Size", selection: Binding(
              get: { if case .original = specification.sizing { 0 } else { 1 } },
              set: { specification.sizing = $0 == 0 ? .original : .fit(maxDimension: fitDimension) }
            )) {
              Text("Original size").tag(0)
              Text("Fit longest edge to").tag(1)
            }.labelsHidden().frame(width: 200)
            if case .fit = specification.sizing {
              TextField("Pixels", value: $fitDimension, format: .number).frame(width: 80).textFieldStyle(.roundedBorder)
                .onChange(of: fitDimension) { _, value in specification.sizing = .fit(maxDimension: min(max(value, 1), 30_000)) }
              Text("px").foregroundStyle(.secondary)
            }
          }
        }
        GridRow {
          Text("Filename")
          VStack(alignment: .leading, spacing: 4) {
            TextField("Template", text: $specification.filenameTemplate).textFieldStyle(.roundedBorder).frame(width: 300)
            Text("Tokens: \(ExportNaming.tokens.joined(separator: " ")) · Example: \(example)").font(.caption).foregroundStyle(.secondary)
          }
        }
        GridRow {
          Text("Metadata")
          VStack(alignment: .leading, spacing: 6) {
            Picker("Metadata", selection: $specification.metadata) {
              ForEach(ExportMetadataPolicy.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().frame(width: 300)
            Toggle("Include location (GPS) when the original has it", isOn: $specification.includeLocation)
              .disabled(specification.metadata != .camera)
          }
        }
        GridRow {
          Text("If a file exists")
          Picker("If a file exists", selection: $specification.conflicts) {
            ForEach(ExportConflictPolicy.allCases) { Text($0.title).tag($0) }
          }.labelsHidden().frame(width: 300)
        }
      }
      Text("Output is 8-bit sRGB with an embedded profile. Sizes never upscale. Edits keep saving while the export runs.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Export") {
          guard let destination else { error = "Choose a folder first."; return }
          persist()
          library.export(specification, to: destination, projectTitle: projectTitle)
          dismiss()
        }.keyboardShortcut(.defaultAction).disabled(destination == nil || selected.isEmpty || library.exporter.isRunning)
      }
    }.padding(28).frame(width: 560)
      .onAppear(perform: restore)
  }

  private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false; panel.prompt = "Export here"
    if panel.runModal() == .OK { destination = panel.url }
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(specification), let text = String(data: data, encoding: .utf8) { storedSpecification = text }
  }
  private func restore() {
    guard let data = storedSpecification.data(using: .utf8),
      let saved = try? JSONDecoder().decode(ExportSpecification.self, from: data) else { return }
    specification = saved
    if case .fit(let value) = saved.sizing { fitDimension = value }
  }
}

/// Progress and outcome of the last export, shown under the workspace header.
public struct ExportStatus: View {
  let library: LibraryController
  private var exporter: ExportController { library.exporter }
  public init(library: LibraryController) { self.library = library }
  public var body: some View {
    if exporter.isRunning || exporter.hasReport {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          if exporter.isRunning {
            ProgressView(value: Double(exporter.completed), total: Double(max(exporter.items.count, 1))).frame(width: 160)
            Text("Exporting \(exporter.completed)/\(exporter.items.count)" + (exporter.current.map { " · \($0)" } ?? ""))
              .font(.caption).lineLimit(1)
            Button("Stop") { exporter.cancel() }.controlSize(.small)
          } else if let summary = exporter.summary {
            Text(summary).font(.caption)
            if let destination = exporter.destination, exporter.exportedCount > 0 {
              Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([destination]) }.controlSize(.small)
            }
            Button("Dismiss") { exporter.dismissReport() }.controlSize(.small)
          }
          Spacer()
        }
        if !exporter.isRunning {
          ForEach(exporter.failures.prefix(5)) { item in
            if case .failed(let message) = item.outcome {
              Text("\(item.filename): \(message)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
          }
          if exporter.failures.count > 5 { Text("… and \(exporter.failures.count - 5) more").font(.caption).foregroundStyle(.secondary) }
          if !exporter.skipped.isEmpty {
            Text("Skipped existing files: \(exporter.skipped.map(\.filename).prefix(6).joined(separator: ", "))" + (exporter.skipped.count > 6 ? "…" : ""))
              .font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
        }
      }.padding(.horizontal, 24).padding(.vertical, 8)
      Divider()
    }
  }
}
