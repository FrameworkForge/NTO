import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct SelectedPhotoCanvas: View {
  let library: LibraryController
  let mode: StudioMode
  let isFocused: Bool
  public init(library: LibraryController, mode: StudioMode, isFocused: Bool) {
    self.library = library; self.mode = mode; self.isFocused = isFocused
  }
  public var body: some View {
    if let photo = library.activePhoto {
      VStack(spacing: 12) {
        PhotoThumbnail(photo: photo, previews: library.previews, size: 2000)
          .accessibilityElement(children: .contain).accessibilityLabel(photo.filename).padding(isFocused ? 0 : 20)
        if !isFocused {
          Text(photo.filename).font(.caption)
          Text(mode == .cull ? "Original preview · culling controls are not available yet"
            : mode == .edit ? "Original preview · editing is not available yet"
            : "Original preview · Cloud publishing is not connected yet")
            .font(.caption).foregroundStyle(.secondary).padding(.bottom, 16)
        }
      }
    } else {
      ContentUnavailableView("Select a photograph", systemImage: "photo",
        description: Text("Choose a photograph in Library. Your selection is kept when you change modes."))
    }
  }
}
