import SwiftUI

/// The Library's single row of pop-ups: what to show, how to sort, search and further filters, an organise menu, count and size.
struct LibraryToolbarRow: View {
  @Bindable var library: LibraryController
  private func binding<T>(_ path: WritableKeyPath<LibraryQuery, T>) -> Binding<T> {
    Binding(get: { library.query[keyPath: path] }, set: { value in
      var query = library.query; query[keyPath: path] = value; library.setQuery(query)
    })
  }
  var body: some View {
    HStack(spacing: 12) {
      Picker("Show", selection: Binding(get: { LibraryShowFilter.current(in: library.query) },
        set: { library.setQuery($0.applied(to: library.query)) })) {
        ForEach(LibraryShowFilter.allCases) { Text($0.title).tag($0) }
      }.fixedSize()
      Picker("Sort by", selection: binding(\.sort)) {
        ForEach(LibrarySort.allCases, id: \.self) { Text($0.title).tag($0) }
      }.fixedSize()
      TextField("Search", text: binding(\.text)).textFieldStyle(.roundedBorder).frame(width: 160)
        .accessibilityLabel("Search filenames, captions, keywords and camera metadata")
      Menu("Filters") {
        Picker("Camera", selection: binding(\.camera)) {
          Text("Any camera").tag("")
          ForEach(Array(Set(library.photos.compactMap(\.camera))).sorted(), id: \.self) { Text($0).tag($0) }
        }
        Picker("Media type", selection: binding(\.mediaType)) {
          Text("Any type").tag("")
          ForEach(Array(Set(library.photos.map(\.mediaType))).sorted(), id: \.self) { Text($0).tag($0) }
        }
        Picker("Minimum rating", selection: binding(\.minimumRating)) {
          Text("Any rating").tag(0)
          ForEach(1...5, id: \.self) { Text("\($0)+ stars").tag($0) }
        }
        Divider()
        Button("Clear filters") {
          var query = LibraryQuery(); query.sort = library.query.sort; query.collectionID = library.query.collectionID
          library.setQuery(query)
        }
      }.fixedSize()
      Menu("Organise") {
        Button(library.activePhoto?.isFavourite == true ? "Remove favourite" : "Favourite") {
          library.annotate(favourite: !(library.activePhoto?.isFavourite ?? false))
        }.disabled(library.actionableIDs.isEmpty)
        Menu("Add selected to collection") {
          ForEach(library.collections) { collection in
            Button(collection.title) { library.collect(in: collection.id, included: true) }
          }
        }.disabled(library.actionableIDs.isEmpty || library.collections.isEmpty)
        if let current = library.collections.first(where: { $0.id == library.query.collectionID }) {
          Button("Remove selected from “\(current.title)”") { library.collect(in: current.id, included: false) }
            .disabled(library.actionableIDs.isEmpty)
        }
      }.fixedSize()
      Spacer()
      Text("\(library.visiblePhotos.count) of \(library.photos.count) · \(library.browsing.selectedIDs.count) selected")
        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      Slider(value: Binding(get: { library.browsing.density }, set: { library.setDensity($0) }), in: 100...280)
        .frame(width: 100).accessibilityLabel("Thumbnail size")
    }
    .padding(.horizontal, 16).frame(height: 40)
  }
}

/// Number keys and flag letters shared by the grid and Cull.
struct CullingKeys: ViewModifier {
  let library: LibraryController
  var activeOnly = false
  func body(content: Content) -> some View {
    content.onKeyPress(characters: CharacterSet(charactersIn: "012345pxfuPXFU")) { press in
      guard press.modifiers.intersection([.command, .control, .option]).isEmpty else { return .ignored }
      let value = press.characters.lowercased()
      if let rating = Int(value) { library.annotate(rating: rating, activeOnly: activeOnly) }
      else if value == "p" { library.annotate(flag: .pick, activeOnly: activeOnly) }
      else if value == "x" { library.annotate(flag: .reject, activeOnly: activeOnly) }
      else if value == "u" { library.annotate(flag: PhotoFlag.none, activeOnly: activeOnly) }
      else if value == "f" { library.annotate(favourite: !(library.activePhoto?.isFavourite ?? false), activeOnly: activeOnly) }
      else { return .ignored }
      return .handled
    }
  }
}

extension LibrarySort {
  var title: String {
    switch self {
    case .imported: "Date Imported"
    case .filename: "Filename"
    case .captured: "Date Captured"
    case .rating: "Rating"
    }
  }
}
