import Foundation
import SwiftData

extension ProjectStore {
  public func setProjectCover(_ photoID: UUID, projectID: UUID) throws {
    guard try photos(in: projectID).contains(where: { $0.id == photoID }) else { throw OrganisationError.invalidMembership }
    let query = FetchDescriptor<LocalProjectPresentation>(predicate: #Predicate { $0.projectID == projectID })
    let saved = try context.fetch(query).first ?? LocalProjectPresentation(projectID: projectID, coverID: photoID)
    if saved.modelContext == nil { context.insert(saved) }
    saved.coverID = photoID
    do { try context.save() } catch { context.rollback(); throw error }
  }
  public func projectOverview(_ projectID: UUID) throws -> (count: Int, cover: PhotoRecord?) {
    var members = FetchDescriptor<LocalPhotoMembership>(predicate: #Predicate { $0.projectID == projectID })
    let count = try context.fetchCount(members)
    let query = FetchDescriptor<LocalProjectPresentation>(predicate: #Predicate { $0.projectID == projectID })
    if let id = try context.fetch(query).first?.coverID {
      let photo = FetchDescriptor<LocalPhoto>(predicate: #Predicate { $0.id == id })
      if let cover = try context.fetch(photo).first { return (count, cover.record) }
    }
    members.fetchLimit = 1
    return (count, try context.fetch(members).first?.photo?.record)
  }
  public func annotate(_ ids: Set<UUID>, rating: Int? = nil, flag: PhotoFlag? = nil,
    favourite: Bool? = nil, caption: String? = nil, keywords: [String]? = nil) throws {
    if let rating, !(0...5).contains(rating) { throw OrganisationError.invalidRating }
    do {
      for id in ids {
        let photoQuery = FetchDescriptor<LocalPhoto>(predicate: #Predicate { $0.id == id })
        guard try context.fetch(photoQuery).first != nil else { throw OrganisationError.invalidMembership }
        let query = FetchDescriptor<LocalPhotoAnnotation>(predicate: #Predicate { $0.photoID == id })
        let annotation = try context.fetch(query).first ?? LocalPhotoAnnotation(photoID: id)
        if annotation.modelContext == nil { context.insert(annotation) }
        if let rating { annotation.rating = rating }
        if let flag { annotation.flag = flag.rawValue }
        if let favourite { annotation.isFavourite = favourite }
        if let caption { annotation.caption = caption }
        if let keywords {
          annotation.keywords = Array(Set(keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        }
      }
      try context.save()
    } catch { context.rollback(); throw error }
  }
  public func libraryQuery(for projectID: UUID) throws -> LibraryQuery {
    let request = FetchDescriptor<LocalLibraryQuery>(predicate: #Predicate { $0.projectID == projectID })
    guard let saved = try context.fetch(request).first else { return LibraryQuery() }
    return try JSONDecoder().decode(LibraryQuery.self, from: saved.data)
  }
  public func saveLibraryQuery(_ query: LibraryQuery, for projectID: UUID) throws {
    let data = try JSONEncoder().encode(query)
    let request = FetchDescriptor<LocalLibraryQuery>(predicate: #Predicate { $0.projectID == projectID })
    let saved = try context.fetch(request).first ?? LocalLibraryQuery(projectID: projectID, data: data)
    if saved.modelContext == nil { context.insert(saved) }
    saved.data = data
    do { try context.save() } catch { context.rollback(); throw error }
  }
  public func collections(in projectID: UUID) throws -> [CollectionRecord] {
    let request = FetchDescriptor<LocalCollection>(predicate: #Predicate { $0.projectID == projectID }, sortBy: [SortDescriptor(\.position)])
    return try context.fetch(request).map { CollectionRecord(id: $0.id, title: $0.title, photoIDs: Set($0.items.map(\.photoID))) }
  }
  @discardableResult public func createCollection(title: String, projectID: UUID) throws -> UUID {
    guard projects.contains(where: { $0.id == projectID }) else { throw PhotoError.projectMissing }
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    var last = FetchDescriptor<LocalCollection>(predicate: #Predicate { $0.projectID == projectID }, sortBy: [SortDescriptor(\.position, order: .reverse)])
    last.fetchLimit = 1
    let position = (try context.fetch(last).first?.position ?? -1) + 1
    let collection = LocalCollection(projectID: projectID, title: title, position: position)
    context.insert(collection)
    do { try context.save(); return collection.id } catch { context.rollback(); throw error }
  }
  private func collection(_ id: UUID) throws -> LocalCollection {
    let request = FetchDescriptor<LocalCollection>(predicate: #Predicate { $0.id == id })
    guard let collection = try context.fetch(request).first else { throw OrganisationError.missingCollection }
    return collection
  }
  public func renameCollection(_ id: UUID, title: String) throws {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    try collection(id).title = title
    do { try context.save() } catch { context.rollback(); throw error }
  }
  public func removeCollection(_ id: UUID) throws {
    context.delete(try collection(id))
    do { try context.save() } catch { context.rollback(); throw error }
  }
  public func moveCollection(_ id: UUID, offset: Int) throws {
    let item = try collection(id)
    var ordered = try collections(in: item.projectID).map(\.id)
    guard let index = ordered.firstIndex(of: id) else { return }
    ordered.remove(at: index); ordered.insert(id, at: min(max(index + offset, 0), ordered.count))
    do {
      for (position, id) in ordered.enumerated() { try collection(id).position = position }
      try context.save()
    } catch { context.rollback(); throw error }
  }
  public func setCollectionMembership(_ ids: Set<UUID>, collectionID: UUID, included: Bool) throws {
    let collection = try collection(collectionID)
    guard ids.isSubset(of: Set(try photos(in: collection.projectID).map(\.id))) else { throw OrganisationError.invalidMembership }
    do {
      if included {
        let existing = Set(collection.items.map(\.photoID))
        for id in ids.subtracting(existing) { collection.items.append(LocalCollectionItem(photoID: id, collection: collection)) }
      } else {
        for item in collection.items.filter({ ids.contains($0.photoID) }) { context.delete(item) }
      }
      try context.save()
    } catch { context.rollback(); throw error }
  }
}
