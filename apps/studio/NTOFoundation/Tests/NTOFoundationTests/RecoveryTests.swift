import XCTest
import ImageIO
import SwiftData
import UniformTypeIdentifiers
@testable import NTOFoundation

/// Studio v0.1 gate: recovery from unavailable originals, interrupted operations and render/export failures without
/// losing work, exercised as one chained workflow on a file-backed library.
final class RecoveryTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
  private func jpeg(_ url: URL, seed: Int) throws {
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = try XCTUnwrap(CGContext(data: nil, width: 96, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(colorSpace: srgb, components: [0.15 + 0.05 * CGFloat(seed), 0.4, 0.5, 1])!)  // distinct bytes per seed
    context.fill(CGRect(x: 0, y: 0, width: 96, height: 64))
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, try XCTUnwrap(context.makeImage()), nil); XCTAssertTrue(CGImageDestinationFinalize(target))
  }

  @MainActor func testWorkflowSurvivesMissingOriginalsCorruptJournalsAndRelinking() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let library = root.appendingPathComponent("Library", isDirectory: true)
    let copies = root.appendingPathComponent("copies", isDirectory: true)
    let referenced = root.appendingPathComponent("referenced", isDirectory: true)
    for folder in [library, copies, referenced] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    for i in 1...3 { try jpeg(copies.appendingPathComponent("Copy-\(i).jpg"), seed: i) }
    try jpeg(referenced.appendingPathComponent("Ref-1.jpg"), seed: 7)
    let locations = LibraryLocations(root: library)
    let storeURL = library.appendingPathComponent("Library.store")
    var projectID: UUID!

    // 1. Import copies and one referenced original, edit, export once.
    do {
      let store = try ProjectStore(container: ProjectStore.container(url: storeURL))
      let project = try store.create(title: "Recovery"); projectID = project.id
      let controller = LibraryController(store: store, locations: locations)
      controller.open(projectID: project.id)
      controller.startImport(urls: [copies], projectID: project.id, storage: .copy, caption: "")
      await controller.waitForImport()
      controller.startImport(urls: [referenced], projectID: project.id, storage: .reference, caption: "")
      await controller.waitForImport()
      XCTAssertEqual(controller.photos.count, 4, controller.issues.joined(separator: "; "))
      let copied = controller.photos.filter { !$0.isReferenced }, refPhoto = try XCTUnwrap(controller.photos.first { $0.isReferenced })
      for photo in copied {
        var history = try store.edits(for: photo.id); var recipe = history.current; recipe.exposure = 0.5
        try history.set(recipe); try store.saveEdits(history)
      }
      let exporter = ExportController(store: store, locations: locations)
      let out = root.appendingPathComponent("out-1")
      exporter.start(ExportSpecification(), photos: controller.photos, projectTitle: "Recovery", destination: out)
      await exporter.waitForCompletion()
      XCTAssertEqual(exporter.exportedCount, 4, exporter.items.map { "\($0.filename): \(String(describing: $0.outcome))" }.joined(separator: " | "))

      // 2. A managed original disappears: rendering and export fail for that photograph only, edits are kept.
      let victim = copied[0]
      let managed = try locations.managedURL(try XCTUnwrap(victim.managedPath))
      let bytes = try Data(contentsOf: managed)
      try FileManager.default.removeItem(at: managed)
      let missingStatus = await controller.previews.originalStatus(victim)
      XCTAssertNotNil(missingStatus, "The inspector reports the missing original")
      let editor = controller.editor
      editor.activate(victim)
      await editor.waitForPreview()
      XCTAssertNotNil(editor.renderError)
      editor.set(\.contrast, value: 0.3)
      XCTAssertTrue(editor.isSaved, "Edits still save while the original is missing")
      XCTAssertEqual(try store.edits(for: victim.id).current.contrast, 0.3)
      let out2 = root.appendingPathComponent("out-2")
      exporter.start(ExportSpecification(), photos: controller.photos, projectTitle: "Recovery", destination: out2)
      await exporter.waitForCompletion()
      XCTAssertEqual(exporter.exportedCount, 3); XCTAssertEqual(exporter.failures.count, 1)
      if case .failed(let message) = exporter.failures[0].outcome { XCTAssertTrue(message.contains("original"), message) } else { XCTFail() }
      // Restore from backup: the same bytes, so the fingerprint check passes and everything works again.
      try bytes.write(to: managed)
      editor.retry(); await editor.waitForPreview()
      XCTAssertNil(editor.renderError); XCTAssertNotNil(editor.previewImage)
      editor.deactivate()

      // 3. A referenced original is lost: a same-volume move is followed by the security-scoped bookmark and needs no
      //    action, so simulate a real loss (copy elsewhere, delete the referenced file). Status reports it; relinking
      //    with identical content recovers it and different content is refused.
      let moved = root.appendingPathComponent("moved", isDirectory: true)
      try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: true)
      let original = referenced.appendingPathComponent("Ref-1.jpg")
      let renamed = referenced.appendingPathComponent("Ref-1-renamed.jpg")
      try FileManager.default.moveItem(at: original, to: renamed)
      let followedStatus = await controller.previews.originalStatus(refPhoto)
      XCTAssertNil(followedStatus, "A same-volume move is followed by the bookmark")
      let newURL = moved.appendingPathComponent("Ref-1-copy.jpg")
      try FileManager.default.copyItem(at: renamed, to: newURL)
      try FileManager.default.removeItem(at: renamed)
      let movedStatus = await controller.previews.originalStatus(refPhoto)
      XCTAssertNotNil(movedStatus, "A deleted referenced original is reported")
      try jpeg(moved.appendingPathComponent("Wrong.jpg"), seed: 9)
      await controller.relink(refPhoto, to: moved.appendingPathComponent("Wrong.jpg"))
      XCTAssertNotNil(controller.errorMessage, "Relinking to different content is refused"); controller.errorMessage = nil
      await controller.relink(refPhoto, to: newURL)
      XCTAssertNil(controller.errorMessage)
      let relinked = try XCTUnwrap(controller.photos.first { $0.id == refPhoto.id })
      XCTAssertEqual(relinked.locationRevision, refPhoto.locationRevision + 1)
      let relinkedStatus = await controller.previews.originalStatus(relinked)
      XCTAssertNil(relinkedStatus)

      // 4. A corrupt edit journal is reported, left in place, and does not affect other photographs or their export.
      let corruptID = copied[1].id
      let request = FetchDescriptor<LocalEditState>(predicate: #Predicate { $0.assetID == corruptID })
      let saved = try XCTUnwrap(store.context.fetch(request).first)
      let garbage = Data("{not a journal".utf8); saved.journal = garbage; try store.context.save()
      XCTAssertThrowsError(try store.edits(for: corruptID))
      XCTAssertEqual(try XCTUnwrap(store.context.fetch(request).first).journal, garbage, "Corrupt bytes are kept for recovery, never overwritten")
      XCTAssertEqual(try store.edits(for: copied[2].id).current.exposure, 0.5)
      let out3 = root.appendingPathComponent("out-3")
      exporter.start(ExportSpecification(), photos: controller.photos, projectTitle: "Recovery", destination: out3)
      await exporter.waitForCompletion()
      XCTAssertEqual(exporter.exportedCount, 3); XCTAssertEqual(exporter.failures.map(\.id), [corruptID])
      controller.flushBrowsing()
    }

    // 5. Reopen from disk: projects, photographs, edits and the relink all persisted.
    let reopened = try ProjectStore(container: ProjectStore.container(url: storeURL))
    let photos = try reopened.photos(in: projectID)
    XCTAssertEqual(photos.count, 4)
    XCTAssertEqual(try reopened.edits(for: photos.first { !$0.isReferenced && $0.filename == "Copy-1.jpg" }!.id).current.contrast, 0.3)
    XCTAssertEqual(photos.first { $0.isReferenced }?.locationRevision, 1)
    XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("out-1/Copy-1.jpg")).isEmpty, false)
  }
}
