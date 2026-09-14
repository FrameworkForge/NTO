import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import NTOFoundation

final class PhotoLibraryTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nto-test-\(UUID())")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
  @discardableResult private func fixture(_ url: URL, type: UTType = .jpeg, seed: Int = 0, orientation: Int = 1) throws -> URL {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: Double(seed % 7) / 7, green: 0.28, blue: 0.38, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
    context.setFillColor(CGColor(gray: 0.8, alpha: 1))
    context.fillEllipse(in: CGRect(x: 60 + seed % 80, y: 80, width: 250, height: 250))
    let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(dest, context.makeImage()!, [
      kCGImagePropertyOrientation: orientation,
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "NTO synthetic camera"],
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:09:13 12:00:00",
        kCGImagePropertyExifFNumber: 2.8, kCGImagePropertyExifISOSpeedRatings: [400],
        kCGImagePropertyExifExposureTime: 0.001, kCGImagePropertyExifFocalLength: 50]
    ] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(dest))
    return url
  }
  @MainActor func testCopyImportDuplicateContentAndReopen() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try fixture(root.appendingPathComponent("source.jpg"), orientation: 6)
    let alias = root.appendingPathComponent("renamed.jpg")
    try FileManager.default.copyItem(at: source, to: alias)
    let originalBytes = try Data(contentsOf: source)
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    try FileManager.default.createDirectory(at: locations.root, withIntermediateDirectories: true)
    let db = locations.root.appendingPathComponent("Library.store")
    var projectID: UUID!
    var photoID: UUID!
    do {
      let store = try ProjectStore(container: ProjectStore.container(url: db))
      let project = try store.create(title: "Test shoot"); projectID = project.id
      let library = LibraryController(store: store, locations: locations)
      library.open(projectID: project.id)
      library.startImport(urls: [source, alias], projectID: project.id, storage: .copy, caption: "Default caption")
      await library.waitForImport()
      XCTAssertEqual(library.imported, 1); XCTAssertEqual(library.duplicates, 1); XCTAssertTrue(library.issues.isEmpty, "\(library.issues)")
      let photo = try XCTUnwrap(library.photos.first); photoID = photo.id
      XCTAssertEqual(photo.width, 480); XCTAssertEqual(photo.height, 640)
      XCTAssertEqual(photo.camera, "NTO synthetic camera"); XCTAssertEqual(photo.caption, "Default caption")
      XCTAssertEqual(try Data(contentsOf: locations.managedURL(try XCTUnwrap(photo.managedPath))), originalBytes)
      library.select(photo.id); library.setDensity(220); library.setScroll(photo.id); library.flushBrowsing()
    }
    let reopened = try ProjectStore(container: ProjectStore.container(url: db))
    XCTAssertEqual(try reopened.photos(in: projectID).map(\.id), [photoID!])
    let state = try reopened.browsingState(for: projectID)
    XCTAssertEqual(state.activeID, photoID); XCTAssertEqual(state.scrollID, photoID); XCTAssertEqual(state.density, 220)
    XCTAssertEqual(try Data(contentsOf: source), originalBytes)
    try FileManager.default.removeItem(at: source)
    let photo = try XCTUnwrap(reopened.photos(in: projectID).first)
    let image = try await PhotoPreviews(locations: locations).image(for: photo, maxPixel: 900)
    XCTAssertEqual(image.width, 480); XCTAssertEqual(image.height, 640)
  }
  @MainActor func testReferenceRelinkAndWrongFileDenial() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try fixture(root.appendingPathComponent("source.jpg"))
    let correct = root.appendingPathComponent("restored.jpg")
    try FileManager.default.copyItem(at: source, to: correct)
    let wrong = try fixture(root.appendingPathComponent("different.jpg"), seed: 3)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let p = try store.create(title: "References")
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    let library = LibraryController(store: store, locations: locations)
    library.open(projectID: p.id)
    library.startImport(urls: [source], projectID: p.id, storage: .reference, caption: "")
    await library.waitForImport()
    let photo = try XCTUnwrap(library.photos.first)
    XCTAssertNil(photo.managedPath); XCTAssertNotNil(photo.bookmark)
    try FileManager.default.removeItem(at: source)
    let missing = await library.previews.originalStatus(photo)
    XCTAssertNotNil(missing)
    await library.relink(photo, to: wrong)
    XCTAssertNotNil(library.errorMessage)
    library.errorMessage = nil
    await library.relink(photo, to: correct)
    XCTAssertNil(library.errorMessage)
    let relinked = try XCTUnwrap(library.photos.first)
    XCTAssertEqual(relinked.id, photo.id); XCTAssertEqual(relinked.fingerprint, photo.fingerprint)
    XCTAssertEqual(relinked.locationRevision, 1)
    let status = await library.previews.originalStatus(relinked)
    XCTAssertNil(status)
    let preview = try await library.previews.image(for: relinked, maxPixel: 900)
    XCTAssertEqual(preview.width, 640)
  }
  @MainActor func testGlobalIdentityReusesOriginalAcrossProjects() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try fixture(root.appendingPathComponent("same.jpg"))
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let p = try store.create(title: "One"); let q = try store.create(title: "Two")
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    let library = LibraryController(store: store, locations: locations)
    for project in [p, q] {
      library.startImport(urls: [source], projectID: project.id, storage: .copy, caption: "")
      await library.waitForImport()
      XCTAssertEqual(library.imported, 1)
    }
    let first = try XCTUnwrap(store.photos(in: p.id).first)
    let second = try XCTUnwrap(store.photos(in: q.id).first)
    XCTAssertEqual(first.id, second.id); XCTAssertEqual(first.managedPath, second.managedPath)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: locations.originals.path).count, 1)
  }
  @MainActor func testMixedFormatsUnsupportedFilesAndCancellation() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let inputs = root.appendingPathComponent("inputs")
    try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
    try fixture(inputs.appendingPathComponent("one.jpg"))
    try fixture(inputs.appendingPathComponent("two.tiff"), type: .tiff, seed: 1)
    try fixture(inputs.appendingPathComponent("three.heic"), type: .heic, seed: 2)
    try Data("not an image".utf8).write(to: inputs.appendingPathComponent("broken.raw"))
    try Data("notes".utf8).write(to: inputs.appendingPathComponent("notes.txt"))
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let p = try store.create(title: "Mixed")
    let library = LibraryController(store: store, locations: LibraryLocations(root: root.appendingPathComponent("library")))
    library.open(projectID: p.id)
    library.startImport(urls: [inputs], projectID: p.id, storage: .copy, caption: "")
    await library.waitForImport()
    XCTAssertEqual(library.imported, 3, "\(library.issues)"); XCTAssertEqual(library.issues.count, 2)
    let ids = library.photos.map(\.id)
    library.startImport(urls: [inputs], projectID: p.id, storage: .copy, caption: "")
    library.cancelImport()
    await library.waitForImport()
    XCTAssertEqual(library.photos.map(\.id), ids)
    XCTAssertFalse(library.isImporting); XCTAssertTrue(library.progress.contains("cancelled"))
  }
  func testCancelledCopyCleansItsStagingDirectory() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try fixture(root.appendingPathComponent("large.jpg"))
    // Trailing data produces a large synthetic source while retaining a decodable JPEG header.
    let writer = try FileHandle(forWritingTo: source)
    try writer.seekToEnd()
    for _ in 0..<128 { try writer.write(contentsOf: Data(repeating: 1, count: 1024 * 1024)) }
    try writer.close()
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    let worker = PhotoImportWorker(locations: locations)
    let inspected = try await worker.inspect(ImportCandidate(url: source), caption: "")
    let task = Task { try await worker.prepare(inspected, source: source, storage: .copy) }
    try await Task.sleep(for: .milliseconds(2))
    task.cancel()
    do { _ = try await task.value; XCTFail("Copy should be cancelled") }
    catch is CancellationError { }
    let folder = locations.originals.appendingPathComponent(inspected.id.uuidString)
    XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }
  func testChangedReferenceCannotProduceNewRenditionAndCacheIsBounded() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try fixture(root.appendingPathComponent("source.jpg"))
    let locations = LibraryLocations(root: root.appendingPathComponent("library"))
    let worker = PhotoImportWorker(locations: locations)
    let inspected = try await worker.inspect(ImportCandidate(url: source), caption: "")
    let photo = try await worker.prepare(inspected, source: source, storage: .reference)
    let previews = PhotoPreviews(locations: locations, diskLimit: 1024)
    _ = try await previews.image(for: photo)
    let bytes = try await previews.cachedByteCount()
    XCTAssertLessThanOrEqual(bytes, 1024)
    try fixture(source, seed: 5)
    do { _ = try await previews.image(for: photo, maxPixel: 900); XCTFail("Changed original was accepted") }
    catch PhotoError.changedOriginal { }
  }
  func testCrashRecoveryOnlyRemovesUncommittedManagedCopies() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let locations = LibraryLocations(root: root)
    let committed = UUID().uuidString, orphan = UUID().uuidString
    for name in [committed, orphan, "unrelated-folder"] {
      try FileManager.default.createDirectory(at: locations.originals.appendingPathComponent(name), withIntermediateDirectories: true)
    }
    let worker = PhotoImportWorker(locations: locations)
    try await worker.recoverUncommittedCopies(keeping: ["\(committed)/original.jpg"])
    XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: locations.originals.path)), [committed, "unrelated-folder"])
    XCTAssertThrowsError(try locations.managedURL("../../outside.jpg"))
  }
  func testRangeAndToggleSelection() {
    let ids = (0..<8).map { _ in UUID() }
    var state = BrowsingState()
    state.select(ids[1], orderedIDs: ids, extend: false, toggle: false)
    state.select(ids[4], orderedIDs: ids, extend: true, toggle: false)
    XCTAssertEqual(state.selectedIDs, Set(ids[1...4]))
    state.select(ids[2], orderedIDs: ids, extend: false, toggle: true)
    XCTAssertEqual(state.selectedIDs, Set([ids[1], ids[3], ids[4]]))
    state.select(ids[7], orderedIDs: ids, extend: false, toggle: true)
    XCTAssertEqual(state.activeID, ids[7]); XCTAssertEqual(state.selectedIDs.count, 4)
  }
  @MainActor func testFoundationDatabaseMigratesWithoutLosingProjects() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("Library.store")
    let id = UUID()
    do {
      let schema = Schema([LocalProject.self])
      let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
      let context = ModelContext(container)
      context.insert(LocalProject(id: id, title: "Existing owner project"))
      try context.save()
    }
    let migrated = try ProjectStore(container: ProjectStore.container(url: url))
    XCTAssertEqual(migrated.projects.first?.id, id)
    XCTAssertEqual(migrated.projects.first?.title, "Existing owner project")
    XCTAssertEqual(try migrated.photos(in: id).count, 0)
  }
  @MainActor func testTenThousandRecordBrowsingAndProjectStateIsolation() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let container = try ProjectStore.container(url: root.appendingPathComponent("Library.store"))
    let store = try ProjectStore(container: container)
    let p = try store.create(title: "Large library"), q = try store.create(title: "Other project")
    for i in 0..<10_000 {
      let record = PhotoRecord(id: UUID(), fingerprint: "synthetic-\(i)", filename: "Photo \(i).jpg",
        mediaType: UTType.jpeg.identifier, width: 640, height: 480, byteCount: 100)
      store.context.insert(LocalPhoto(record, projectID: p.id))
    }
    try store.context.save()
    let library = LibraryController(store: store, locations: LibraryLocations(root: root))
    let start = ContinuousClock.now
    library.open(projectID: p.id)
    let elapsed = ContinuousClock.now - start
    print("10,000-record Library open: \(elapsed)")
    XCTAssertEqual(library.photos.count, 10_000)
    // Hosted CI runners are several times slower than a development Mac; the local regression budget stays tight.
    let budget: Duration = ProcessInfo.processInfo.environment["CI"] != nil ? .seconds(20) : .seconds(5)
    XCTAssertLessThan(elapsed, budget)
    let ratingStart = ContinuousClock.now
    let reviewIDs = Array(library.photos.prefix(50).map(\.id))
    for id in reviewIDs { library.select(id); library.annotate(rating: 4, activeOnly: true) }
    let ratingElapsed = ContinuousClock.now - ratingStart
    print("50 saved ratings in 10,000-record library: \(ratingElapsed)")
    XCTAssertLessThan(ratingElapsed, .seconds(5))
    XCTAssertTrue(try store.photos(in: p.id).filter { reviewIDs.contains($0.id) }.allSatisfy { $0.rating == 4 })
    let selected = library.photos[5].id
    library.select(selected); library.setDensity(200); library.setScroll(selected)
    library.open(projectID: q.id)
    XCTAssertTrue(library.photos.isEmpty); XCTAssertNil(library.browsing.activeID)
    library.open(projectID: p.id)
    XCTAssertEqual(library.browsing.activeID, selected)
    XCTAssertEqual(library.browsing.scrollID, selected); XCTAssertEqual(library.browsing.density, 200)
  }
  @MainActor func testCreateOptionalStressLibrary() throws {
    guard let path = ProcessInfo.processInfo.environment["NTO_QA_STRESS_LIBRARY"] else { throw XCTSkip("Opt-in isolated UI stress library generator") }
    let root = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let locations = LibraryLocations(root: root)
    let sourceFolder = locations.originals.appendingPathComponent("synthetic", isDirectory: true)
    try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
    try fixture(sourceFolder.appendingPathComponent("original.jpg"))
    let store = try ProjectStore(container: ProjectStore.container(url: root.appendingPathComponent("Library.store")))
    let project = try store.create(title: "10,000 synthetic records")
    for i in 0..<10_000 {
      // Isolated UI stress data: unique records backed by one generated image. This does not
      // represent a real mixed-camera import benchmark or valid production content identities.
      let record = PhotoRecord(id: UUID(), fingerprint: "synthetic-stress-\(i)",
        filename: String(format: "Study-%05d.jpg", i + 1), mediaType: UTType.jpeg.identifier,
        width: 640, height: 480, byteCount: 10_000, caption: "Synthetic UI stress fixture",
        managedPath: "synthetic/original.jpg")
      store.context.insert(LocalPhoto(record, projectID: project.id))
    }
    try store.context.save()
  }
  func testCreateOptionalManualVerificationFixtures() throws {
    guard let path = ProcessInfo.processInfo.environment["NTO_QA_FIXTURES"] else { throw XCTSkip("Opt-in manual image fixture generator") }
    let root = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for i in 1...12 { try fixture(root.appendingPathComponent(String(format: "Study-%02d.jpg", i)), seed: i) }
    try fixture(root.appendingPathComponent("Study-portrait.tiff"), type: .tiff, seed: 4, orientation: 6)
    try fixture(root.appendingPathComponent("Study-heic.heic"), type: .heic, seed: 6)
    try Data("Deliberately unsupported QA file".utf8).write(to: root.appendingPathComponent("Notes.txt"))
  }
}
