import Foundation
import Observation
import SwiftData

@Model public final class LocalProject {
  @Attribute(.unique) public var id: UUID
  public var title: String
  public var createdAt: Date
  public init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
  }
}
@MainActor @Observable public final class ProjectStore {
  public private(set) var projects: [LocalProject] = []
  let context: ModelContext
  public init(container: ModelContainer) throws {
    context = ModelContext(container)
    context.autosaveEnabled = false
    try reload()
  }
  public static func container(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema([LocalProject.self, LocalPhoto.self, LocalPhotoMembership.self, LocalBrowsingState.self, LocalPhotoAnnotation.self, LocalLibraryQuery.self, LocalCollection.self, LocalCollectionItem.self, LocalProjectPresentation.self, LocalEditState.self])
    let config: ModelConfiguration
    if let url {
      config = ModelConfiguration(schema: schema, url: url)
    } else if inMemory {
      config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    } else {
      let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("NTO/Studio", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("Library.store"), cloudKitDatabase: .none)
    }
    return try ModelContainer(for: schema, configurations: [config])
  }
  private func reload() throws {
    projects = try context.fetch(
      FetchDescriptor<LocalProject>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
  }
  @discardableResult public func create(title: String) throws -> LocalProject {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    let project = LocalProject(title: title)
    context.insert(project)
    do {
      try context.save()
      try reload()
      return project
    } catch {
      context.rollback()
      throw error
    }
  }
  public func rename(_ project: LocalProject, title: String) throws {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    project.title = title
    do {
      try context.save()
      try reload()
    } catch {
      context.rollback()
      throw error
    }
  }
}
public enum StoreError: LocalizedError {
  case emptyTitle
  public var errorDescription: String? { "Give this project a name before saving." }
}
