import Foundation
import SwiftData

extension ProjectStore {
  public func photos(in projectID: UUID) throws -> [PhotoRecord] {
    var descriptor = FetchDescriptor<LocalPhotoMembership>(predicate: #Predicate { $0.projectID == projectID })
    descriptor.relationshipKeyPathsForPrefetching = [\.photo]
    let annotations = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<LocalPhotoAnnotation>()).map { ($0.photoID, $0) })
    return try context.fetch(descriptor).compactMap { membership -> PhotoRecord? in
      guard var record = membership.photo?.record else { return nil }
      if let annotation = annotations[record.id] {
        record.rating = annotation.rating; record.flag = PhotoFlag(rawValue: annotation.flag) ?? .none
        record.isFavourite = annotation.isFavourite; record.keywords = annotation.keywords
        record.caption = annotation.caption ?? record.caption
      }
      return record
    }.sorted {
      $0.importedAt == $1.importedAt ? $0.filename.localizedStandardCompare($1.filename) == .orderedAscending : $0.importedAt < $1.importedAt
    }
  }
  public func photo(fingerprint: String) throws -> LocalPhoto? {
    var query = FetchDescriptor<LocalPhoto>(predicate: #Predicate { $0.fingerprint == fingerprint })
    query.fetchLimit = 1
    return try context.fetch(query).first
  }
  public func allManagedPaths() throws -> Set<String> {
    Set(try context.fetch(FetchDescriptor<LocalPhoto>()).compactMap(\.managedPath))
  }
  @discardableResult public func add(_ record: PhotoRecord, to projectID: UUID) throws -> Bool {
    guard projects.contains(where: { $0.id == projectID }) else { throw PhotoError.projectMissing }
    if let existing = try photo(fingerprint: record.fingerprint) {
      guard !existing.memberships.contains(where: { $0.projectID == projectID }) else { return false }
      existing.memberships.append(LocalPhotoMembership(projectID: projectID, photo: existing))
    } else {
      context.insert(LocalPhoto(record, projectID: projectID))
    }
    do { try context.save(); return true }
    catch { context.rollback(); throw error }
  }
  public func relink(id: UUID, bookmark: Data) throws {
    let query = FetchDescriptor<LocalPhoto>(predicate: #Predicate { $0.id == id })
    guard let photo = try context.fetch(query).first, photo.managedPath == nil else {
      throw PhotoError.notReferenced
    }
    photo.bookmark = bookmark
    photo.locationRevision += 1
    do { try context.save() } catch { context.rollback(); throw error }
  }
  public func browsingState(for projectID: UUID) throws -> BrowsingState {
    let query = FetchDescriptor<LocalBrowsingState>(predicate: #Predicate { $0.projectID == projectID })
    guard let saved = try context.fetch(query).first else { return BrowsingState() }
    var state = BrowsingState()
    state.selectedIDs = Set(saved.selectedIDs); state.activeID = saved.activeID
    state.anchorID = saved.anchorID; state.scrollID = saved.scrollID
    state.density = saved.density
    return state
  }
  public func saveBrowsingState(_ state: BrowsingState, for projectID: UUID) throws {
    let query = FetchDescriptor<LocalBrowsingState>(predicate: #Predicate { $0.projectID == projectID })
    let saved = try context.fetch(query).first ?? LocalBrowsingState(projectID: projectID)
    if saved.modelContext == nil { context.insert(saved) }
    saved.selectedIDs = Array(state.selectedIDs); saved.activeID = state.activeID
    saved.anchorID = state.anchorID; saved.scrollID = state.scrollID; saved.density = state.density
    do { try context.save() } catch { context.rollback(); throw error }
  }
}
