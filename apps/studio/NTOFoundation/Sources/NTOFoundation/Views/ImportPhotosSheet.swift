import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ImportPhotosSheet: View {
  @Bindable var library: LibraryController
  let store: ProjectStore
  let initialURLs: [URL]
  let onImport: (UUID) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var urls: [URL] = []
  @State private var destination: UUID?
  @State private var newTitle = ""
  @State private var caption = ""
  @State private var storage = ImportStorage.copy
  @State private var error: String?
  public init(library: LibraryController, store: ProjectStore, initialURLs: [URL], onImport: @escaping (UUID) -> Void) {
    self.library = library; self.store = store; self.initialURLs = initialURLs; self.onImport = onImport
  }
  public var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Import photographs").font(.title2)
      Text("JPEG, HEIC, TIFF and RAW supported by this Mac.").font(.callout).foregroundStyle(.secondary)
      HStack {
        Button("Choose files or folders…") {
          let panel = NSOpenPanel()
          panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
          panel.prompt = "Choose"
          if panel.runModal() == .OK { urls = panel.urls }
        }
        Spacer()
        Text("\(urls.count) source\(urls.count == 1 ? "" : "s") selected").font(.caption)
      }
      if !urls.isEmpty {
        ScrollView {
          VStack(alignment: .leading) {
            ForEach(urls, id: \.self) { Text($0.lastPathComponent).font(.caption).lineLimit(1) }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: 70)
      }
      Picker("Destination", selection: $destination) {
        Text("New project…").tag(nil as UUID?)
        ForEach(store.projects, id: \.id) { Text($0.title).tag(Optional($0.id)) }
      }
      if destination == nil { TextField("New project name", text: $newTitle).textFieldStyle(.roundedBorder) }
      Picker("Originals", selection: $storage) {
        ForEach(ImportStorage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }.pickerStyle(.segmented)
      Text(storage == .copy
        ? "Studio keeps its own copy. Your source files remain unchanged. Allow enough disk space for the originals."
        : "Files stay in their current location. Keep the source drive connected; Studio stores a reference, not a backup.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      TextField("Default caption (optional)", text: $caption).textFieldStyle(.roundedBorder)
      Text("Identical file contents are added once per project. Organising an existing asset in another project reuses its original storage choice.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      if let error { Text(error).foregroundStyle(.red).font(.caption) }
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Import") {
          do {
            let id = try destination ?? store.create(title: newTitle).id
            library.startImport(urls: urls, projectID: id, storage: storage, caption: caption)
            onImport(id); dismiss()
          } catch { self.error = error.localizedDescription }
        }.keyboardShortcut(.defaultAction)
          .disabled(urls.isEmpty || library.isImporting || (destination == nil && newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
      }
    }.padding(28).frame(width: 470)
      .onAppear { urls = initialURLs; destination = library.projectID }
  }
}
