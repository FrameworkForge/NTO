import SwiftUI

/// Cull: the photograph, a floating control bar, a filmstrip. Filters are shared with Library and live in its row.
struct CullWorkspace: View {
  let library: LibraryController
  let isFocused: Bool
  @State private var inspecting = false
  @FocusState private var canvasFocused: Bool
  private var photo: PhotoRecord? { library.visiblePhotos.first { $0.id == library.browsing.activeID } }
  private var position: String? {
    guard let photo, let index = library.visiblePhotos.firstIndex(of: photo) else { return nil }
    return "\(index + 1) of \(library.visiblePhotos.count)"
  }
  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        Color.black
        if let photo {
          if inspecting { PixelInspection(photo: photo, previews: library.previews).id(photo.id) }
          else { PhotoThumbnail(photo: photo, previews: library.previews, size: 2000).padding(isFocused ? 0 : 24) }
        } else {
          ContentUnavailableView {
            Label(library.visiblePhotos.isEmpty ? "No matching photographs" : "Choose a photograph", systemImage: "photo")
          } description: {
            Text("Use the arrow keys or the filmstrip. What is shown follows the Library.")
          } actions: {
            Button("Select first photograph") { library.navigate(1); canvasFocused = true }.disabled(library.visiblePhotos.isEmpty)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay(alignment: .bottom) { if let photo { controlBar(photo).padding(.bottom, 16) } }
      .overlay(alignment: .topTrailing) {
        if let position { Text(position).font(.caption).foregroundStyle(.secondary).padding(14) }
      }
      .overlay(alignment: .topLeading) {
        if let photo { Text(photo.filename).font(.caption).foregroundStyle(.secondary).padding(14) }
      }
      .contentShape(Rectangle()).onTapGesture { canvasFocused = true }
      .focusable().focused($canvasFocused).focusEffectDisabled()
      if !isFocused {
        Divider()
        Filmstrip(library: library) { canvasFocused = true }
      }
    }
    .background(CullKeyboardShortcuts { event in
      switch event.keyCode {
      case 123: library.navigate(-1)
      case 124: library.navigate(1)
      case 49: if !event.isARepeat { inspecting.toggle() }
      default:
        guard !event.isARepeat else { return false }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if let rating = Int(key), (0...5).contains(rating) { library.annotate(rating: rating, activeOnly: true) }
        else if key == "p" { library.annotate(flag: .pick, activeOnly: true) }
        else if key == "x" { library.annotate(flag: .reject, activeOnly: true) }
        else if key == "u" { library.annotate(flag: PhotoFlag.none, activeOnly: true) }
        else if key == "f" { library.annotate(favourite: !(library.activePhoto?.isFavourite ?? false), activeOnly: true) }
        else { return false }
      }
      return true
    }.frame(width: 0, height: 0))
    .onAppear { canvasFocused = true; library.prefetch(around: library.browsing.activeID.map { [$0] } ?? [], maxPixel: 2000) }
    .onChange(of: library.browsing.activeID) { _, id in library.prefetch(around: id.map { [$0] } ?? [], maxPixel: 2000) }
  }

  private func controlBar(_ photo: PhotoRecord) -> some View {
    HStack(spacing: 6) {
      Button { library.navigate(-1); canvasFocused = true } label: { Image(systemName: "chevron.left") }
        .accessibilityLabel("Previous photograph").help("Previous (←)")
      RatingStars(rating: photo.rating) { library.annotate(rating: $0, activeOnly: true) }.padding(.horizontal, 6)
      Divider().frame(height: 16)
      FlagSegment(flag: photo.flag) { library.annotate(flag: $0, activeOnly: true) }
      Button { library.annotate(favourite: !photo.isFavourite, activeOnly: true) } label: {
        Image(systemName: photo.isFavourite ? "heart.fill" : "heart")
      }.accessibilityLabel("Toggle favourite").help("Favourite (F)")
      Divider().frame(height: 16)
      Toggle(inspecting ? "Fit" : "100%", isOn: $inspecting).toggleStyle(.button).help("Fit or 100% (Space)")
      Button { library.navigate(1); canvasFocused = true } label: { Image(systemName: "chevron.right") }
        .accessibilityLabel("Next photograph").help("Next (→)")
    }
    .floatingBar()
  }
}

struct Filmstrip: View {
  let library: LibraryController
  var onSelect: () -> Void = {}
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        LazyHStack(spacing: 6) {
          ForEach(library.visiblePhotos) { item in
            Button {
              library.select(item.id); onSelect()
            } label: {
              PhotoThumbnail(photo: item, previews: library.previews).frame(width: 84, height: 56)
                .clipShape(.rect(cornerRadius: 3))
                .overlay { RoundedRectangle(cornerRadius: 3).stroke(item.id == library.browsing.activeID ? Color.white : Color.clear, lineWidth: 2) }
            }.buttonStyle(.plain).accessibilityLabel(item.filename)
              .accessibilityValue(item.id == library.browsing.activeID ? "Selected" : "Not selected").id(item.id)
          }
        }.padding(.horizontal, 12).padding(.vertical, 10)
      }.frame(height: 78)
        .onChange(of: library.browsing.activeID) { _, id in if let id { withAnimation(.easeOut(duration: NTOTokens.Motion.standard)) { proxy.scrollTo(id, anchor: .center) } } }
        .onAppear { if let id = library.browsing.activeID { proxy.scrollTo(id, anchor: .center) } }
    }
  }
}
