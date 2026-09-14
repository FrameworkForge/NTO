import Foundation
import SwiftData

/// Local-only persistence. Bookmarks and managed paths never enter Cloud DTOs.
@Model public final class LocalPhoto {
  @Attribute(.unique) public var id: UUID
  @Attribute(.unique) public var fingerprint: String
  @Relationship(deleteRule: .cascade, inverse: \LocalPhotoMembership.photo)
  public var memberships: [LocalPhotoMembership]
  public var filename: String
  public var mediaType: String
  public var width: Int
  public var height: Int
  public var byteCount: Int64
  public var importedAt: Date
  public var capturedAt: String?
  public var camera: String?
  public var lens: String?
  public var exposure: String?
  public var caption: String
  public var bookmark: Data?
  public var managedPath: String?
  public var locationRevision: Int

  public init(_ photo: PhotoRecord, projectID: UUID) {
    id = photo.id; fingerprint = photo.fingerprint; memberships = []
    filename = photo.filename; mediaType = photo.mediaType
    width = photo.width; height = photo.height; byteCount = photo.byteCount
    importedAt = photo.importedAt; capturedAt = photo.capturedAt
    camera = photo.camera; lens = photo.lens; exposure = photo.exposure
    caption = photo.caption; bookmark = photo.bookmark; managedPath = photo.managedPath
    locationRevision = photo.locationRevision
    memberships = [LocalPhotoMembership(projectID: projectID, photo: self)]
  }
  public var record: PhotoRecord {
    PhotoRecord(id: id, fingerprint: fingerprint, filename: filename, mediaType: mediaType,
      width: width, height: height, byteCount: byteCount, importedAt: importedAt,
      capturedAt: capturedAt, camera: camera, lens: lens, exposure: exposure, caption: caption,
      bookmark: bookmark, managedPath: managedPath, locationRevision: locationRevision)
  }
}

@Model public final class LocalPhotoMembership {
  #Index<LocalPhotoMembership>([\.projectID])
  @Attribute(.unique) public var key: String
  public var projectID: UUID
  public var photo: LocalPhoto?
  public init(projectID: UUID, photo: LocalPhoto) {
    self.projectID = projectID; self.photo = photo
    key = "\(projectID.uuidString)/\(photo.id.uuidString)"
  }
}

public struct PhotoRecord: Identifiable, Sendable, Equatable {
  public var id: UUID
  public var fingerprint: String
  public var filename: String
  public var mediaType: String
  public var width: Int
  public var height: Int
  public var byteCount: Int64
  public var importedAt: Date = .now
  public var capturedAt: String?
  public var camera: String?
  public var lens: String?
  public var exposure: String?
  public var caption: String = ""
  public var bookmark: Data?
  public var managedPath: String?
  public var locationRevision: Int = 0
  public var rating: Int = 0
  public var flag: PhotoFlag = .none
  public var isFavourite: Bool = false
  public var keywords: [String] = []
  public var isReferenced: Bool { managedPath == nil }
}

@Model public final class LocalBrowsingState {
  @Attribute(.unique) public var projectID: UUID
  public var selectedIDs: [UUID]
  public var activeID: UUID?
  public var anchorID: UUID?
  public var scrollID: UUID?
  public var density: Double
  public init(projectID: UUID) {
    self.projectID = projectID; selectedIDs = []; density = 160
  }
}

public struct BrowsingState: Sendable, Equatable {
  public var selectedIDs: Set<UUID> = []
  public var activeID: UUID?
  public var anchorID: UUID?
  public var scrollID: UUID?
  public var density: Double = 160
  public init() {}

  public mutating func select(_ id: UUID, orderedIDs: [UUID], extend: Bool, toggle: Bool) {
    if extend, let anchorID, let start = orderedIDs.firstIndex(of: anchorID),
      let end = orderedIDs.firstIndex(of: id) {
      let range = Set(orderedIDs[min(start, end)...max(start, end)])
      selectedIDs = toggle ? selectedIDs.union(range) : range
      activeID = id
    } else if toggle {
      if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
      activeID = selectedIDs.contains(id) ? id : orderedIDs.first { selectedIDs.contains($0) }
      anchorID = id
    } else {
      selectedIDs = [id]; activeID = id; anchorID = id
    }
  }
}
