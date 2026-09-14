import SwiftUI

/// Publish: a draft form shaped by the `Publication` contract. Choosing a cover is real (it is the project cover);
/// destination, visibility and downloads are draft settings, and publishing itself is not connected in this build.
public struct PublishWorkspace: View {
  let library: LibraryController
  let projectTitle: String
  let projectCoverID: UUID?
  let setCover: (UUID) -> Void
  @State private var destination = "gallery"
  @State private var visibility = "unlisted"
  @State private var downloads = "web"
  public init(library: LibraryController, projectTitle: String, projectCoverID: UUID?, setCover: @escaping (UUID) -> Void) {
    self.library = library; self.projectTitle = projectTitle; self.projectCoverID = projectCoverID; self.setCover = setCover
  }
  private var sequence: [PhotoRecord] {
    let selected = library.visiblePhotos.filter { library.actionableIDs.contains($0.id) }
    return selected.isEmpty ? library.visiblePhotos : selected
  }
  private var slug: String {
    let lowered = projectTitle.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
    return lowered.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "project" : lowered.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
  }
  public var body: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 4) {
          Text(projectTitle.isEmpty ? "No Project" : projectTitle).font(.title2.weight(.bold))
          Text("Draft · Not published").foregroundStyle(.secondary)
        }
      }
      Section {
        Picker("Destination", selection: $destination) { Text("Gallery").tag("gallery"); Text("Portfolio").tag("portfolio") }
          .pickerStyle(.segmented)
        Picker("Visibility", selection: $visibility) { Text("Public").tag("public"); Text("Unlisted").tag("unlisted"); Text("Password").tag("password") }
        Picker("Downloads", selection: $downloads) { Text("None").tag("none"); Text("Web").tag("web"); Text("Master").tag("master") }
        LabeledContent("Link") {
          Text("nto.motion/\(destination == "portfolio" ? "projects" : "galleries")/\(slug)").font(.callout.monospaced()).foregroundStyle(.secondary)
        }
      } footer: {
        Text("Draft settings follow the Publication contract. They are not saved until publishing exists.").font(.caption).foregroundStyle(.secondary)
      }
      Section {
        if sequence.isEmpty {
          Text("Import photographs to choose a cover.").foregroundStyle(.secondary)
        } else {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(sequence) { photo in
              Button { setCover(photo.id) } label: {
                PhotoThumbnail(photo: photo, previews: library.previews)
                  .frame(height: 64).clipShape(.rect(cornerRadius: 4))
                  .overlay { RoundedRectangle(cornerRadius: 4).stroke(projectCoverID == photo.id ? Color.white : Color.clear, lineWidth: 2.5) }
              }.buttonStyle(.plain).accessibilityLabel(photo.filename)
                .accessibilityValue(projectCoverID == photo.id ? "Cover" : "")
            }
          }
        }
      } header: { Text("Cover") } footer: {
        Text("The cover is saved with the project and shown in the sidebar. \(library.actionableIDs.isEmpty ? "Select photographs in Library to narrow this sequence." : "Showing the current selection.")")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        HStack {
          Spacer()
          Button("Preview") {}.disabled(true)
          Button("Publish") {}.buttonStyle(.borderedProminent).disabled(true)
        }
      } footer: {
        Text("Publishing to nto.motion arrives with Cloud (roadmap Phases 08–10). Nothing is uploaded from this build.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped).frame(maxWidth: 620)
  }
}
