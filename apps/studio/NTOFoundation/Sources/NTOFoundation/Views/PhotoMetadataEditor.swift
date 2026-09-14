import SwiftUI

struct PhotoMetadataEditor: View {
  let library: LibraryController
  let photo: PhotoRecord
  @State private var editing = false
  @State private var caption = ""
  @State private var keywords = ""
  @State private var applyToSelection = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button("Edit Caption and Keywords…") {
        caption = photo.caption; keywords = photo.keywords.joined(separator: ", "); applyToSelection = false; editing = true
      }
    }.sheet(isPresented: $editing) {
      VStack(alignment: .leading, spacing: 14) {
        Text("Photo metadata").font(.headline)
        TextField("Caption", text: $caption, axis: .vertical).lineLimit(3...6)
        TextField("Keywords, separated by commas", text: $keywords)
        Toggle("Replace metadata on all \(library.actionableIDs.count) selected photographs", isOn: $applyToSelection)
          .disabled(library.actionableIDs.count < 2)
        Text("Saved in Studio. Original files and camera metadata stay unchanged.").font(.caption)
        HStack {
          Button("Cancel") { editing = false }.keyboardShortcut(.cancelAction)
          Spacer()
          Button("Save") {
            library.annotate(caption: caption, keywords: keywords.components(separatedBy: ","), activeOnly: !applyToSelection)
            editing = false
          }.keyboardShortcut(.defaultAction)
        }
      }.textFieldStyle(.roundedBorder).padding(24).frame(width: 440)
    }
  }
}
