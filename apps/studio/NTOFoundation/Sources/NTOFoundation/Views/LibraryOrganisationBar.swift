import SwiftUI

struct LibraryOrganisationBar: View {
  let library: LibraryController
  @State private var collectionSheet = false
  @State private var editingID: UUID?
  @State private var title = ""
  private func binding<T>(_ path: WritableKeyPath<LibraryQuery, T>) -> Binding<T> {
    Binding(get: { library.query[keyPath: path] }, set: { value in
      var query = library.query; query[keyPath: path] = value; library.setQuery(query)
    })
  }
  var body: some View {
    VStack(spacing: 8) {
      HStack {
        TextField("Search photographs", text: binding(\.text)).textFieldStyle(.roundedBorder)
          .accessibilityLabel("Search filenames, captions, keywords and camera metadata")
        Menu("Filters") {
          Picker("Minimum rating", selection: binding(\.minimumRating)) {
            Text("Any rating").tag(0)
            ForEach(1...5, id: \.self) { Text("\($0)+ stars").tag($0) }
          }
          Picker("Flag", selection: binding(\.flag)) {
            Text("Any flag").tag("all")
            ForEach(PhotoFlag.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) }
          }
          Toggle("Favourites only", isOn: binding(\.favouritesOnly))
          Picker("Camera", selection: binding(\.camera)) {
            Text("Any camera").tag("")
            ForEach(Array(Set(library.photos.compactMap(\.camera))).sorted(), id: \.self) { Text($0).tag($0) }
          }
          Picker("Media type", selection: binding(\.mediaType)) {
            Text("Any type").tag("")
            ForEach(Array(Set(library.photos.map(\.mediaType))).sorted(), id: \.self) { Text($0).tag($0) }
          }
          Button("Clear filters") {
            var query = LibraryQuery(); query.sort = library.query.sort; query.collectionID = library.query.collectionID
            library.setQuery(query)
          }
        }.fixedSize()
        Picker("Sort", selection: binding(\.sort)) {
          ForEach(LibrarySort.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.frame(width: 145)
      }
      HStack {
        Picker("Collection", selection: binding(\.collectionID)) {
          Text("All photographs").tag(nil as UUID?)
          ForEach(library.collections) { Text("\($0.title) (\($0.photoIDs.count))").tag(Optional($0.id)) }
        }
        Menu("Collections") {
          Button("New collection…") { editingID = nil; title = ""; collectionSheet = true }
          if let current = library.collections.first(where: { $0.id == library.query.collectionID }) {
            Button("Rename collection…") { editingID = current.id; title = current.title; collectionSheet = true }
            Button("Move earlier") { library.moveCollection(current.id, offset: -1) }
            Button("Move later") { library.moveCollection(current.id, offset: 1) }
            Button("Remove selected from collection") { library.collect(in: current.id, included: false) }
              .disabled(library.actionableIDs.isEmpty)
            Button("Remove collection (keep photographs)") { library.removeCollection(current.id) }
          }
          Menu("Add selected to") {
            ForEach(library.collections) { collection in
              Button(collection.title) { library.collect(in: collection.id, included: true) }
            }
          }.disabled(library.actionableIDs.isEmpty || library.collections.isEmpty)
        }.fixedSize()
        TextField("Capture date", text: binding(\.captureDate)).textFieldStyle(.roundedBorder).frame(width: 110)
          .help("Match capture metadata, for example 2026:09")
      }
    }.padding(.horizontal, 20).padding(.top, 12)
    .sheet(isPresented: $collectionSheet) {
      VStack(alignment: .leading, spacing: 16) {
        Text(editingID == nil ? "New collection" : "Rename collection").font(.headline)
        TextField("Collection name", text: $title).textFieldStyle(.roundedBorder)
        Text("Collections organise this project’s photographs without moving originals.").font(.caption)
        HStack {
          Button("Cancel") { collectionSheet = false }.keyboardShortcut(.cancelAction)
          Spacer()
          Button("Save") {
            if let editingID { library.renameCollection(editingID, title: title) }
            else { library.createCollection(title: title) }
            collectionSheet = false
          }.keyboardShortcut(.defaultAction).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }.padding(24).frame(width: 360)
    }
  }
}

struct PhotoRatingControls: View {
  let library: LibraryController
  var activeOnly = false
  var body: some View {
    HStack(spacing: 8) {
      Menu("★ \(library.activePhoto?.rating ?? 0)") {
        ForEach(0...5, id: \.self) { rating in
          Button(rating == 0 ? "Unrated" : "\(rating) stars") { library.annotate(rating: rating, activeOnly: activeOnly) }
        }
      }.accessibilityLabel("Rating")
      Menu(library.activePhoto?.flag.rawValue.capitalized ?? "Flag") {
        ForEach(PhotoFlag.allCases, id: \.self) { flag in
          Button(flag.rawValue.capitalized) { library.annotate(flag: flag, activeOnly: activeOnly) }
        }
      }.accessibilityLabel("Flag")
      Button {
        library.annotate(favourite: !(library.activePhoto?.isFavourite ?? false), activeOnly: activeOnly)
      } label: { Image(systemName: library.activePhoto?.isFavourite == true ? "heart.fill" : "heart") }
        .accessibilityLabel("Toggle favourite")
    }.disabled(library.actionableIDs.isEmpty)
  }
}

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
