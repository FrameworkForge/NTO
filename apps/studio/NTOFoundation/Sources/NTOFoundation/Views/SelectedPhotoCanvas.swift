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
    if mode == .edit {
      EditWorkspace(library: library, isFocused: isFocused)
    } else if mode == .cull {
      CullWorkspace(library: library, isFocused: isFocused)
    } else if let photo = library.activePhoto {
      ZStack {
        Color.black
        PhotoThumbnail(photo: photo, previews: library.previews, size: 2000)
          .accessibilityElement(children: .contain).accessibilityLabel(photo.filename).padding(isFocused ? 0 : 24)
      }.overlay(alignment: .topLeading) { Text(photo.filename).font(.caption).foregroundStyle(.secondary).padding(14) }
    } else {
      ContentUnavailableView("Select a photograph", systemImage: "photo",
        description: Text("Choose a photograph in Library. Your selection is kept when you change modes."))
    }
  }
}
