import SwiftUI

struct CullWorkspace: View {
  let library: LibraryController
  let isFocused: Bool
  @State private var inspecting = false
  @State private var filmstrip = true
  @FocusState private var canvasFocused: Bool
  private var photo: PhotoRecord? { library.visiblePhotos.first { $0.id == library.browsing.activeID } }
  var body: some View {
    VStack(spacing: 8) {
      if !isFocused {
        LibraryOrganisationBar(library: library)
        HStack {
          Button("Previous", systemImage: "chevron.left") { library.navigate(-1); canvasFocused = true }
          Button("Next", systemImage: "chevron.right") { library.navigate(1); canvasFocused = true }
          Spacer()
          PhotoRatingControls(library: library, activeOnly: true)
          Button(inspecting ? "Fit" : "100%") { inspecting.toggle(); canvasFocused = true }.disabled(photo == nil)
          Toggle("Filmstrip", isOn: $filmstrip).toggleStyle(.button)
        }.padding(.horizontal, 20)
      }
      Group {
        if let photo {
          if inspecting { PixelInspection(photo: photo, previews: library.previews).id(photo.id) }
          else { PhotoThumbnail(photo: photo, previews: library.previews, size: 2000).padding(isFocused ? 0 : 12) }
        } else {
          ContentUnavailableView {
            Label(library.visiblePhotos.isEmpty ? "No matching photographs" : "Choose a photograph", systemImage: "photo")
          } description: {
            Text("Use the arrow keys or choose a photograph below. Filters remain shared with Library.")
          } actions: {
            Button("Select first photograph") { library.navigate(1); canvasFocused = true }.disabled(library.visiblePhotos.isEmpty)
          }
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()).onTapGesture { canvasFocused = true }
        .focusable().focused($canvasFocused).focusEffectDisabled()
      if !isFocused {
        Text(photo.map { "\($0.filename) · \($0.rating) stars · \($0.flag.rawValue)\($0.isFavourite ? " · Favourite" : "")" } ?? "No visible selection")
          .font(.caption).lineLimit(1)
        Text("← → Navigate   0–5 Rate   P Pick   X Reject   U Clear flag   F Favourite   Space Fit / 100%")
          .font(.caption2).foregroundStyle(.secondary)
        if filmstrip {
          ScrollViewReader { proxy in
            ScrollView(.horizontal) {
              LazyHStack(spacing: 8) {
                ForEach(library.visiblePhotos) { item in
                  Button {
                    library.select(item.id); canvasFocused = true
                  } label: {
                    PhotoThumbnail(photo: item, previews: library.previews).frame(width: 86, height: 66)
                      .padding(3).border(item.id == library.browsing.activeID ? Color.primary : Color.clear, width: 2)
                  }.buttonStyle(.plain).accessibilityLabel(item.filename)
                    .accessibilityValue(item.id == library.browsing.activeID ? "Selected" : "Not selected").id(item.id)
                }
              }.padding(.horizontal, 20)
            }.frame(height: 82)
              .onChange(of: library.browsing.activeID) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
              .onAppear { if let id = library.browsing.activeID { proxy.scrollTo(id, anchor: .center) } }
          }
        }
      }
    }.background(CullKeyboardShortcuts { event in
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
}

private struct PixelInspection: View {
  let photo: PhotoRecord
  let previews: PhotoPreviews
  @Environment(\.displayScale) private var displayScale
  @State private var image: CGImage?
  @State private var error: String?
  @State private var retry = 0
  var body: some View {
    Group {
      if let image {
        ScrollView([.horizontal, .vertical]) {
          Image(decorative: image, scale: displayScale)
            .resizable().interpolation(.none)
            .frame(width: CGFloat(image.width) / displayScale, height: CGFloat(image.height) / displayScale)
        }.defaultScrollAnchor(.center).accessibilityLabel("100 percent original, one image pixel per display pixel. Scroll to inspect.")
      } else if let error {
        ContentUnavailableView {
          Label("100% inspection unavailable", systemImage: "exclamationmark.triangle")
        } description: { Text(error) } actions: { Button("Retry") { retry += 1 } }
      } else { ProgressView("Loading original at 100%…") }
    }.task(id: "\(photo.id)-\(photo.locationRevision)-\(retry)") {
      image = nil; error = nil
      do {
        let decoded = try await previews.fullResolution(for: photo)
        if !Task.isCancelled { image = decoded }
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }.onDisappear { image = nil }
  }
}
