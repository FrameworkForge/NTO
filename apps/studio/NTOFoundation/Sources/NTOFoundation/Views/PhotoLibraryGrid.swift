import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The contact sheet: a pop-up row, then square tiles with a flag dot and stars. Selection, keyboard navigation,
/// scroll position and density persist per project as before.
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
        LibraryToolbarRow(library: library)
        Divider()
      }
      GeometryReader { geometry in
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: library.browsing.density), spacing: 8)], spacing: 8) {
            ForEach(library.visiblePhotos) { photo in
              tile(photo).id(photo.id)
            }
          }.scrollTargetLayout().padding(16)
        }
        .overlay {
          if library.visiblePhotos.isEmpty {
            ContentUnavailableView("No matching photographs", systemImage: "line.3.horizontal.decrease", description: Text("Change what is shown, clear the filters, or choose another collection."))
          }
        }
        .scrollPosition(id: $scrollID, anchor: .top)
        .onChange(of: scrollID) { _, id in library.setScroll(id) }
        .onAppear { scrollID = library.browsing.scrollID }
        .onScrollTargetVisibilityChange(idType: UUID.self) { ids in library.prefetch(around: ids) }
        .focusable().focused($gridFocused).focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
          if press.key == .return { if library.activePhoto != nil { onOpen() }; return .handled }
          let columns = max(1, Int((geometry.size.width - 32) / (library.browsing.density + 8)))
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
      if !isFocused {
        Divider()
        LibraryFooter(library: library)
      }
    }
  }
  private func tile(_ photo: PhotoRecord) -> some View {
    let selected = library.browsing.selectedIDs.contains(photo.id)
    return Button {
      let flags = NSEvent.modifierFlags
      library.select(photo.id, extend: flags.contains(.shift), toggle: flags.contains(.command))
      gridFocused = true
    } label: {
      PhotoThumbnail(photo: photo, previews: library.previews)
        .frame(height: library.browsing.density * 0.75)
        .clipShape(.rect(cornerRadius: 4))
        .overlay(alignment: .topLeading) { FlagDot(flag: photo.flag).padding(8) }
        .overlay(alignment: .bottomLeading) {
          if photo.rating > 0 || photo.isFavourite {
            Text((photo.rating > 0 ? String(repeating: "★", count: photo.rating) : "") + (photo.isFavourite ? " ♥" : ""))
              .font(.caption2).foregroundStyle(.white).shadow(radius: 2).padding(8)
          }
        }
        .overlay { RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.white : Color.clear, lineWidth: 3) }
        .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityLabel(photo.filename)
      .accessibilityValue("\(photo.rating) stars\(photo.flag == .none ? "" : ", \(photo.flag.rawValue)")\(selected ? ", selected" : "")")
      .accessibilityAddTraits(selected ? [.isSelected] : [])
      .help(photo.filename)
      .contextMenu {
        Button("View photograph") { library.select(photo.id); onOpen() }
        Menu("Add to collection") {
          ForEach(library.collections) { collection in
            Button(collection.title) { library.select(photo.id); library.collect(in: collection.id, included: true) }
          }
        }.disabled(library.collections.isEmpty)
      }
      .simultaneousGesture(TapGesture(count: 2).onEnded { _ in library.select(photo.id); onOpen() })
  }
}
