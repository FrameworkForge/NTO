import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct PhotoLibraryGrid: View {
  @Bindable var library: LibraryController
  let onOpen: () -> Void
  let isFocused: Bool
  @State private var scrollID: UUID?
  @FocusState private var gridFocused: Bool
  public init(library: LibraryController, isFocused: Bool = false, onOpen: @escaping () -> Void) {
    self.library = library; self.onOpen = onOpen; self.isFocused = isFocused
  }
  public var body: some View {
    VStack(spacing: 0) {
      if !isFocused {
      LibraryOrganisationBar(library: library)
      HStack {
        Text("\(library.visiblePhotos.count) of \(library.photos.count) photographs · \(library.browsing.selectedIDs.count) selected")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        PhotoRatingControls(library: library)
        Image(systemName: "square.grid.3x3").accessibilityHidden(true)
        Slider(value: Binding(get: { library.browsing.density }, set: { library.setDensity($0) }), in: 100...280)
          .frame(width: 100).accessibilityLabel("Thumbnail size")
      }.padding(.horizontal, 20).padding(.vertical, 12)
      }
      GeometryReader { geometry in
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: library.browsing.density), spacing: 12)], spacing: 16) {
            ForEach(library.visiblePhotos) { photo in
              tile(photo).id(photo.id)
            }
          }.scrollTargetLayout().padding(20)
        }
        .overlay {
          if library.visiblePhotos.isEmpty {
            ContentUnavailableView("No matching photographs", systemImage: "line.3.horizontal.decrease", description: Text("Change your filters or choose another collection."))
          }
        }
        .scrollPosition(id: $scrollID, anchor: .top)
        .onChange(of: scrollID) { _, id in library.setScroll(id) }
        .onAppear { scrollID = library.browsing.scrollID }
        .onScrollTargetVisibilityChange(idType: UUID.self) { ids in library.prefetch(around: ids) }
        .focusable().focused($gridFocused).focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
          if press.key == .return { if library.activePhoto != nil { onOpen() }; return .handled }
          let columns = max(1, Int((geometry.size.width - 40) / (library.browsing.density + 12)))
          let delta = press.key == .leftArrow ? -1 : press.key == .rightArrow ? 1 : press.key == .upArrow ? -columns : columns
          let ids = library.visiblePhotos.map(\.id)
          guard !ids.isEmpty else { return .ignored }
          let current = library.browsing.activeID.flatMap { ids.firstIndex(of: $0) } ?? (delta > 0 ? -1 : 0)
          let id = ids[min(max(current + delta, 0), ids.count - 1)]
          library.select(id, extend: press.modifiers.contains(.shift))
          scrollID = id
          return .handled
        }
        .modifier(CullingKeys(library: library))
        .onKeyPress(keys: ["a"]) { press in
          guard press.modifiers.contains(.command) else { return .ignored }
          library.selectAll(); return .handled
        }
      }
    }
  }
  private func tile(_ photo: PhotoRecord) -> some View {
              Button {
                let flags = NSEvent.modifierFlags
                library.select(photo.id, extend: flags.contains(.shift), toggle: flags.contains(.command))
                gridFocused = true
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  PhotoThumbnail(photo: photo, previews: library.previews)
                    .frame(height: library.browsing.density * 0.8)
                  if !isFocused {
                    Text(photo.filename).font(.caption).lineLimit(1).foregroundStyle(.primary)
                    Text("\(String(repeating: "★", count: photo.rating)) \(photo.flag == .none ? "" : photo.flag.rawValue.capitalized) \(photo.isFavourite ? "♥" : "")")
                      .font(.caption2).foregroundStyle(.secondary)
                  }
                }.padding(5).overlay {
                  RoundedRectangle(cornerRadius: 3).stroke(
                    library.browsing.selectedIDs.contains(photo.id) ? Color.white : Color.clear, lineWidth: 2)
                }.contentShape(Rectangle())
              }.buttonStyle(.plain)
                .accessibilityLabel(photo.filename)
                .accessibilityValue(library.browsing.selectedIDs.contains(photo.id) ? "Selected" : "Not selected")
                .accessibilityAddTraits(library.browsing.selectedIDs.contains(photo.id) ? [.isSelected] : [])
                .contextMenu {
                  Button("View photograph") { library.select(photo.id); onOpen() }
                }
                .simultaneousGesture(TapGesture(count: 2).onEnded { _ in library.select(photo.id); onOpen() })
  }

}
