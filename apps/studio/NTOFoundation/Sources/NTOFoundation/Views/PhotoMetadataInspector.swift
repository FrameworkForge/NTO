import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct PhotoMetadataInspector: View {
  let library: LibraryController
  @State private var status: String?
  @State private var checking = false
  @State private var refresh = 0
  public init(library: LibraryController) { self.library = library }
  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("INSPECTOR").font(.caption).foregroundStyle(.secondary)
        if let photo = library.activePhoto {
          Text(photo.filename).font(.headline).textSelection(.enabled)
          Text("\(photo.width) × \(photo.height)\n\(ByteCountFormatter.string(fromByteCount: photo.byteCount, countStyle: .file))")
            .font(.caption).foregroundStyle(.secondary)
          if let camera = photo.camera { Text(camera) }
          if let lens = photo.lens { Text(lens).font(.caption) }
          if let exposure = photo.exposure { Text(exposure).font(.caption) }
          if let captured = photo.capturedAt { Text(captured).font(.caption) }
          if !photo.caption.isEmpty { Text(photo.caption).font(.callout).textSelection(.enabled) }
          PhotoMetadataEditor(library: library, photo: photo).id(photo.id)
          Divider()
          Text(photo.isReferenced ? "Referenced original" : "Studio-managed copy").font(.caption)
          if checking { ProgressView("Checking original…").controlSize(.small) }
          else if let status {
            Text(status).font(.caption).foregroundStyle(.secondary)
            Button("Check again") { refresh += 1 }
          } else { Label("Original available", systemImage: "checkmark.circle").font(.caption) }
          if photo.isReferenced {
            Button("Locate original…") {
              let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
              panel.prompt = "Locate original"
              if panel.runModal() == .OK, let url = panel.url {
                Task { await library.relink(photo, to: url); refresh += 1 }
              }
            }
          }
          Text("Capture metadata is read-only. Ratings, flags, captions and keywords are saved locally.")
            .font(.caption).foregroundStyle(.secondary)
        } else { Text("No photograph selected").foregroundStyle(.secondary) }
      }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
    }
    .task(id: "\(library.activePhoto?.id.uuidString ?? "none")-\(library.activePhoto?.locationRevision ?? 0)-\(refresh)") {
      guard let photo = library.activePhoto else { status = nil; return }
      checking = true
      let result = await library.previews.originalStatus(photo)
      if !Task.isCancelled { status = result; checking = false }
    }
  }
}
