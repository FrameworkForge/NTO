import SwiftUI

public struct ProjectSummaryLabel: View {
  let project: LocalProject
  let store: ProjectStore
  let library: LibraryController
  let revision: Int
  @State private var count = 0
  @State private var cover: PhotoRecord?
  @State private var failed = false
  public init(project: LocalProject, store: ProjectStore, library: LibraryController, revision: Int) {
    self.project = project; self.store = store; self.library = library; self.revision = revision
  }
  public var body: some View {
    Label {
      Text(project.title).lineLimit(1)
    } icon: {
      if let cover { PhotoThumbnail(photo: cover, previews: library.previews).frame(width: 18, height: 14).clipShape(.rect(cornerRadius: 2)) }
      else { Image(systemName: "folder") }
    }
    .badge(failed ? 0 : count)
    .help(failed ? "Summary unavailable" : "\(count) photographs · created \(project.createdAt.formatted(.dateTime.day().month().year()))")
    .task(id: "\(revision)-\(library.photos.count)-\(library.projectID?.uuidString ?? "")") {
      do { (count, cover) = try store.projectOverview(project.id); failed = false }
      catch { failed = true }
    }
  }
}
