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
    HStack(spacing: 8) {
      if let cover { PhotoThumbnail(photo: cover, previews: library.previews).frame(width: 34, height: 40) }
      else { Image(systemName: "folder").frame(width: 34, height: 40).foregroundStyle(.secondary) }
      VStack(alignment: .leading, spacing: 3) {
        Text(project.title).lineLimit(2)
        Text(failed ? "Summary unavailable" : "\(count) photos · \(project.createdAt.formatted(.dateTime.day().month().year()))")
          .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.task(id: "\(revision)-\(library.photos.count)-\(library.projectID?.uuidString ?? "")") {
      do { (count, cover) = try store.projectOverview(project.id); failed = false }
      catch { failed = true }
    }
  }
}
