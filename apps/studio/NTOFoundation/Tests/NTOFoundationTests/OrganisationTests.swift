import XCTest
import SwiftData
import ImageIO
import UniformTypeIdentifiers
@testable import NTOFoundation

final class OrganisationTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
  private func photo(_ name: String, camera: String = "Camera A") -> PhotoRecord {
    PhotoRecord(id: UUID(), fingerprint: UUID().uuidString, filename: name, mediaType: "public.jpeg",
      width: 640, height: 480, byteCount: 100, capturedAt: "2026:09:13 10:00:00", camera: camera, caption: "Original caption")
  }
  @MainActor func testAnnotationsCollectionsAndCoverSurviveReopenWithoutChangingOriginalRecord() throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let db = root.appendingPathComponent("Library.store")
    let original = photo("one.jpg")
    var projectID: UUID!, secondID: UUID!, collectionID: UUID!
    do {
      let store = try ProjectStore(container: ProjectStore.container(url: db))
      projectID = try store.create(title: "Shoot").id; secondID = try store.create(title: "Other").id
      try store.add(original, to: projectID); try store.add(original, to: secondID)
      collectionID = try store.createCollection(title: "Selects", projectID: projectID)
      let other = try store.createCollection(title: "Story", projectID: projectID)
      try store.setCollectionMembership([original.id], collectionID: collectionID, included: true)
      try store.setCollectionMembership([original.id], collectionID: collectionID, included: true)
      try store.setCollectionMembership([original.id], collectionID: other, included: true)
      try store.moveCollection(other, offset: -1)
      XCTAssertEqual(try store.collections(in: projectID).map(\.id), [other, collectionID])
      try store.renameCollection(collectionID, title: "Final selects")
      try store.annotate([original.id], rating: 5, flag: .pick, favourite: true, caption: "New caption", keywords: [" portrait ", "portrait", "", "studio"])
      try store.setProjectCover(original.id, projectID: projectID)
      try store.removeCollection(other)
      let appended = try store.createCollection(title: "Later collection", projectID: projectID)
      XCTAssertEqual(try store.collections(in: projectID).map(\.id), [collectionID, appended])
      try store.removeCollection(appended)
      XCTAssertEqual(try store.photos(in: projectID).count, 1)
      XCTAssertEqual(try store.photo(fingerprint: original.fingerprint)?.record, original)
      XCTAssertThrowsError(try store.annotate([original.id], rating: 6))
    }
    let reopened = try ProjectStore(container: ProjectStore.container(url: db))
    let result = try XCTUnwrap(reopened.photos(in: projectID).first)
    XCTAssertEqual(result.rating, 5); XCTAssertEqual(result.flag, .pick); XCTAssertTrue(result.isFavourite)
    XCTAssertEqual(result.caption, "New caption"); XCTAssertEqual(result.keywords, ["portrait", "studio"])
    XCTAssertEqual(try reopened.photos(in: secondID).first?.rating, 5)
    XCTAssertEqual(try reopened.collections(in: projectID).first?.photoIDs, [original.id])
    XCTAssertEqual(try reopened.collections(in: projectID).first?.title, "Final selects")
    XCTAssertEqual(try reopened.projectOverview(projectID).cover?.id, original.id)
    try reopened.setCollectionMembership([original.id], collectionID: collectionID, included: false)
    XCTAssertEqual(try reopened.collections(in: projectID).first?.photoIDs, [])
    XCTAssertEqual(try reopened.photos(in: projectID).count, 1)
    try reopened.removeCollection(collectionID)
    XCTAssertTrue(try reopened.collections(in: projectID).isEmpty)
    XCTAssertEqual(try reopened.photos(in: projectID).first?.id, original.id)
  }
  @MainActor func testCollectionRejectsCrossProjectMembershipAndBatchRollsBack() throws {
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let a = try store.create(title: "A"), b = try store.create(title: "B")
    let record = photo("one.jpg"); try store.add(record, to: a.id)
    let collection = try store.createCollection(title: "B only", projectID: b.id)
    XCTAssertThrowsError(try store.setCollectionMembership([record.id], collectionID: collection, included: true))
    XCTAssertThrowsError(try store.annotate([record.id, UUID()], rating: 4))
    XCTAssertEqual(try store.photos(in: a.id).first?.rating, 0)
    XCTAssertThrowsError(try store.setProjectCover(record.id, projectID: b.id))
  }
  @MainActor func testFiltersSelectionPersistenceAndRapidCullWrites() throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let db = root.appendingPathComponent("Library.store")
    let store = try ProjectStore(container: ProjectStore.container(url: db))
    let a = try store.create(title: "A"), b = try store.create(title: "B")
    var records: [PhotoRecord] = []
    for index in 0..<25 { let record = photo("photo-\(index).jpg"); records.append(record); try store.add(record, to: a.id) }
    let library = LibraryController(store: store, locations: LibraryLocations(root: root)); library.open(projectID: a.id)
    for record in records { library.select(record.id); library.annotate(rating: 4, flag: .pick, activeOnly: true) }
    XCTAssertTrue(library.photos.allSatisfy { $0.rating == 4 && $0.flag == .pick })
    library.select(records[0].id)
    var query = LibraryQuery(); query.text = "photo-1.jpg"; query.minimumRating = 4; query.sort = .filename
    library.setQuery(query)
    XCTAssertEqual(library.visiblePhotos.map(\.id), [records[1].id])
    XCTAssertEqual(library.browsing.activeID, records[0].id, "Filtering must preserve the stored selection")
    library.annotate(rating: 1)
    XCTAssertEqual(library.photos.first { $0.id == records[0].id }?.rating, 4, "Hidden selection must not be edited")
    library.selectAll(); library.annotate(rating: 5)
    library.setScroll(records[1].id); library.flushBrowsing()
    library.open(projectID: b.id); XCTAssertEqual(library.query, LibraryQuery())
    library.open(projectID: a.id); XCTAssertEqual(library.query, query)
    XCTAssertEqual(library.browsing.scrollID, records[1].id)
    let reopened = try ProjectStore(container: ProjectStore.container(url: db))
    XCTAssertEqual(try reopened.libraryQuery(for: a.id), query)
    XCTAssertEqual(try reopened.photos(in: a.id).first { $0.id == records[1].id }?.rating, 5)
    query = LibraryQuery(); query.flag = "pick"; library.setQuery(query); library.select(records[0].id)
    library.annotate(flag: .reject, activeOnly: true)
    XCTAssertNotEqual(library.browsing.activeID, records[0].id, "Cull advances when the active photo leaves the filter")
  }
  func testCombinedMetadataFiltersAndDeterministicSorting() {
    var a = photo("a.jpg"), b = photo("b.jpg", camera: "Camera B")
    a.rating = 5; a.flag = .pick; a.isFavourite = true; a.keywords = ["portrait"]
    b.rating = 3
    var query = LibraryQuery()
    query.text = "PORTRAIT"; query.camera = "Camera A"; query.mediaType = "public.jpeg"
    query.captureDate = "2026:09"; query.minimumRating = 4; query.flag = "pick"; query.favouritesOnly = true
    XCTAssertEqual(query.apply(to: [b, a]).map(\.id), [a.id])
    XCTAssertTrue(query.apply(to: [b, a], members: [b.id]).isEmpty)
    query = LibraryQuery(); query.sort = .rating
    XCTAssertEqual(query.apply(to: [b, a]).map(\.id), [a.id, b.id])
  }
  @MainActor func testPhaseTwoSchemaMigratesWithPhotosAndBrowsingIntact() throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let db = root.appendingPathComponent("Library.store"), record = photo("existing.jpg")
    let projectID = UUID()
    do {
      let schema = Schema([LocalProject.self, LocalPhoto.self, LocalPhotoMembership.self, LocalBrowsingState.self])
      let old = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: db)])
      let context = ModelContext(old)
      context.insert(LocalProject(id: projectID, title: "Existing shoot"))
      context.insert(LocalPhoto(record, projectID: projectID))
      let browsing = LocalBrowsingState(projectID: projectID); browsing.activeID = record.id; browsing.selectedIDs = [record.id]
      context.insert(browsing); try context.save()
    }
    let upgraded = try ProjectStore(container: ProjectStore.container(url: db))
    XCTAssertEqual(upgraded.projects.first?.title, "Existing shoot")
    XCTAssertEqual(try upgraded.photos(in: projectID).first, record)
    XCTAssertEqual(try upgraded.browsingState(for: projectID).activeID, record.id)
    try upgraded.annotate([record.id], rating: 3)
    XCTAssertEqual(try upgraded.photos(in: projectID).first?.rating, 3)
  }
  @MainActor func testFullResolutionIsOrientedAndDoesNotUsePreviewCache() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("source.jpg")
    let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    let image = try XCTUnwrap(context.makeImage())
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(target))
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    let worker = PhotoImportWorker(locations: locations)
    let inspected = try await worker.inspect(ImportCandidate(url: url), caption: "")
    let prepared = try await worker.prepare(inspected, source: url, storage: .copy)
    let previews = PhotoPreviews(locations: locations)
    let full = try await previews.fullResolution(for: prepared)
    XCTAssertEqual(full.width, 480); XCTAssertEqual(full.height, 640)
    let cacheSize = try await previews.cachedByteCount(); XCTAssertEqual(cacheSize, 0)
  }
}

extension OrganisationTests {
  func testShowFilterMapsToAndFromQueriesWithoutTouchingSearchOrSort() {
    var query = LibraryQuery(); query.text = "stair"; query.sort = .rating; query.camera = "Canon"
    XCTAssertEqual(LibraryShowFilter.current(in: query), .all)
    for filter in LibraryShowFilter.allCases {
      let applied = filter.applied(to: query)
      XCTAssertEqual(LibraryShowFilter.current(in: applied), filter, filter.title)
      XCTAssertEqual(applied.text, "stair"); XCTAssertEqual(applied.sort, .rating); XCTAssertEqual(applied.camera, "Canon")
    }
    let photos = [
      PhotoRecord(id: UUID(), fingerprint: "a", filename: "a.jpg", mediaType: "public.jpeg", width: 1, height: 1, byteCount: 1, rating: 0, flag: .pick),
      PhotoRecord(id: UUID(), fingerprint: "b", filename: "b.jpg", mediaType: "public.jpeg", width: 1, height: 1, byteCount: 1, rating: 4, flag: .none, isFavourite: true),
      PhotoRecord(id: UUID(), fingerprint: "c", filename: "c.jpg", mediaType: "public.jpeg", width: 1, height: 1, byteCount: 1, rating: 2, flag: .reject),
    ]
    let base = LibraryQuery()
    XCTAssertEqual(LibraryShowFilter.picks.applied(to: base).apply(to: photos).map(\.filename), ["a.jpg"])
    XCTAssertEqual(LibraryShowFilter.rejects.applied(to: base).apply(to: photos).map(\.filename), ["c.jpg"])
    XCTAssertEqual(LibraryShowFilter.favourites.applied(to: base).apply(to: photos).map(\.filename), ["b.jpg"])
    XCTAssertEqual(LibraryShowFilter.rated.applied(to: base).apply(to: photos).map(\.filename), ["b.jpg"])
    XCTAssertEqual(LibraryShowFilter.unrated.applied(to: base).apply(to: photos).map(\.filename), ["a.jpg"])
    XCTAssertEqual(LibraryShowFilter.all.applied(to: LibraryShowFilter.unrated.applied(to: base)).apply(to: photos).count, 3)
  }
}
