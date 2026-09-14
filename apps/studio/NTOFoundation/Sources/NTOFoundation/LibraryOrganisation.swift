import Foundation
import SwiftData

public enum PhotoFlag: String, Codable, CaseIterable, Sendable { case none, pick, reject }
public enum LibrarySort: String, Codable, CaseIterable, Sendable { case imported, filename, captured, rating }
public struct LibraryQuery: Codable, Equatable, Sendable {
  public var text = ""
  public var minimumRating = 0
  public var flag = "all"
  public var favouritesOnly = false
  public var camera = ""
  public var mediaType = ""
  public var captureDate = ""
  public var sort: LibrarySort = .imported
  public var collectionID: UUID?
  public init() {}
  public func apply(to photos: [PhotoRecord], members: Set<UUID>? = nil) -> [PhotoRecord] {
    photos.filter { p in
      (members == nil || members!.contains(p.id)) && p.rating >= minimumRating &&
      (flag == "all" || (flag == "unrated" ? p.rating == 0 : p.flag.rawValue == flag)) && (!favouritesOnly || p.isFavourite) &&
      (camera.isEmpty || p.camera == camera) && (mediaType.isEmpty || p.mediaType == mediaType) &&
      (captureDate.isEmpty || (p.capturedAt ?? "").contains(captureDate)) &&
      (text.isEmpty || ([p.filename, p.caption, p.camera ?? "", p.lens ?? ""] + p.keywords)
        .joined(separator: " ").localizedStandardContains(text))
    }.sorted { a, b in
      switch sort {
      case .rating: if a.rating != b.rating { return a.rating > b.rating }
      case .filename: if a.filename != b.filename { return a.filename.localizedStandardCompare(b.filename) == .orderedAscending }
      case .captured: if a.capturedAt != b.capturedAt { return (a.capturedAt ?? "") < (b.capturedAt ?? "") }
      case .imported: break
      }
      if a.importedAt != b.importedAt { return a.importedAt < b.importedAt }
      return a.id.uuidString < b.id.uuidString
    }
  }
}

// Additive models leave Phase 02 originals and memberships intact during migration.
@Model public final class LocalPhotoAnnotation {
  @Attribute(.unique) public var photoID: UUID
  public var rating: Int = 0
  public var flag: String = "none"
  public var isFavourite: Bool = false
  public var caption: String?
  public var keywords: [String] = []
  public init(photoID: UUID) { self.photoID = photoID }
}
@Model public final class LocalLibraryQuery {
  @Attribute(.unique) public var projectID: UUID
  public var data: Data
  public init(projectID: UUID, data: Data) { self.projectID = projectID; self.data = data }
}
@Model public final class LocalCollection {
  @Attribute(.unique) public var id: UUID
  public var projectID: UUID
  public var title: String
  public var position: Int
  @Relationship(deleteRule: .cascade, inverse: \LocalCollectionItem.collection)
  public var items: [LocalCollectionItem] = []
  public init(projectID: UUID, title: String, position: Int) {
    id = UUID(); self.projectID = projectID; self.title = title; self.position = position
  }
}
@Model public final class LocalCollectionItem {
  @Attribute(.unique) public var key: String
  public var photoID: UUID
  public var collection: LocalCollection?
  public init(photoID: UUID, collection: LocalCollection) {
    self.photoID = photoID; self.collection = collection
    key = "\(collection.id)/\(photoID)"
  }
}
public struct CollectionRecord: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var title: String
  public var photoIDs: Set<UUID>
}
public enum OrganisationError: LocalizedError {
  case invalidRating, missingCollection, invalidMembership
  public var errorDescription: String? {
    switch self {
    case .invalidRating: "Ratings must be between zero and five."
    case .missingCollection: "This collection is no longer available."
    case .invalidMembership: "Only photographs in this project can be added to its collections."
    }
  }
}

@Model public final class LocalProjectPresentation {
  @Attribute(.unique) public var projectID: UUID
  public var coverID: UUID?
  public init(projectID: UUID, coverID: UUID?) { self.projectID = projectID; self.coverID = coverID }
}

/// The Library's "Show" pop-up: one of a few named views over the flag, favourite and rating filters.
/// Search, camera, media type and sort are separate and untouched by choosing one.
public enum LibraryShowFilter: String, CaseIterable, Identifiable, Sendable {
  case all, picks, rejects, favourites, rated, unrated
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .all: "All Photographs"
    case .picks: "Picks"
    case .rejects: "Rejects"
    case .favourites: "Favourites"
    case .rated: "Rated 4 or Higher"
    case .unrated: "Unrated"
    }
  }
  /// The view a query currently represents, `.all` when it matches none exactly.
  public static func current(in query: LibraryQuery) -> LibraryShowFilter {
    if query.flag == PhotoFlag.pick.rawValue { return .picks }
    if query.flag == PhotoFlag.reject.rawValue { return .rejects }
    if query.favouritesOnly { return .favourites }
    if query.minimumRating >= 4 { return .rated }
    if query.flag == "unrated" { return .unrated }
    return .all
  }
  public func applied(to query: LibraryQuery) -> LibraryQuery {
    var next = query
    next.flag = "all"; next.favouritesOnly = false; next.minimumRating = 0
    switch self {
    case .all: break
    case .picks: next.flag = PhotoFlag.pick.rawValue
    case .rejects: next.flag = PhotoFlag.reject.rawValue
    case .favourites: next.favouritesOnly = true
    case .rated: next.minimumRating = 4
    case .unrated: next.flag = "unrated"
    }
    return next
  }
}
