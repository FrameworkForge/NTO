import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Info inspector for Library and Cull: a grouped form with the photograph's identity, rating and flag,
/// read-only capture metadata, caption and keywords, and the original's availability.
public struct PhotoMetadataInspector: View {
  let library: LibraryController
  @State private var status: String?
  @State private var checking = false
  @State private var refresh = 0
  public init(library: LibraryController) { self.library = library }
  public var body: some View {
    if let photo = library.activePhoto {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 4) {
            Text(photo.filename).font(.headline).textSelection(.enabled)
            Text("\(photo.width) × \(photo.height) · \(ByteCountFormatter.string(fromByteCount: photo.byteCount, countStyle: .file))")
              .font(.caption).foregroundStyle(.secondary)
          }
          HStack {
            RatingStars(rating: photo.rating) { library.annotate(rating: $0, activeOnly: true) }
            Spacer()
            FlagSegment(flag: photo.flag) { library.annotate(flag: $0, activeOnly: true) }
            Button { library.annotate(favourite: !photo.isFavourite, activeOnly: true) } label: {
              Image(systemName: photo.isFavourite ? "heart.fill" : "heart")
            }.buttonStyle(.borderless).accessibilityLabel("Toggle favourite")
          }
        }
        Section {
          LabeledContent("Camera", value: photo.camera ?? "—")
          LabeledContent("Lens", value: photo.lens ?? "—")
          LabeledContent("Exposure", value: photo.exposure ?? "—")
          LabeledContent("Captured", value: photo.capturedAt ?? "—")
          LabeledContent("Original", value: photo.isReferenced ? "Referenced" : "Studio copy")
        } footer: {
          Text("Capture metadata is read-only.").font(.caption).foregroundStyle(.secondary)
        }
        Section {
          if !photo.caption.isEmpty { Text(photo.caption).textSelection(.enabled) }
          if !photo.keywords.isEmpty { Text(photo.keywords.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
          PhotoMetadataEditor(library: library, photo: photo).id(photo.id)
        } header: { Text("Caption and Keywords") }
        Section {
          if checking { ProgressView("Checking original…").controlSize(.small) }
          else if let status {
            Label(status, systemImage: "exclamationmark.triangle").font(.caption)
            Button("Check Again") { refresh += 1 }.controlSize(.small)
          } else { Label("Original available", systemImage: "checkmark.circle").font(.caption) }
          if photo.isReferenced {
            Button("Locate Original…") {
              let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
              panel.prompt = "Locate original"
              if panel.runModal() == .OK, let url = panel.url {
                Task { await library.relink(photo, to: url); refresh += 1 }
              }
            }.controlSize(.small)
          }
        } header: { Text("Original") }
      }
      .formStyle(.grouped)
      .task(id: "\(photo.id.uuidString)-\(photo.locationRevision)-\(refresh)") {
        checking = true
        let result = await library.previews.originalStatus(photo)
        if !Task.isCancelled { status = result; checking = false }
      }
    } else {
      ContentUnavailableView("No Selection", systemImage: "photo", description: Text("Choose a photograph to see its details."))
    }
  }
}
