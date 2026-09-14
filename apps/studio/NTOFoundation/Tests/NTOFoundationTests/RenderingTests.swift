import XCTest
import CoreImage
import ImageIO
import SwiftData
import UniformTypeIdentifiers
@testable import NTOFoundation

final class RenderingTests: XCTestCase {
  private func fixture() throws -> (URL, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("gradient.png")
    let context = try XCTUnwrap(CGContext(data: nil, width: 256, height: 192, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    for x in 0..<256 {
      context.setFillColor(CGColor(red: CGFloat(x) / 512 + 0.05, green: 0.25, blue: 0.1, alpha: 1))
      context.fill(CGRect(x: x, y: 0, width: 1, height: 192))
    }
    let image = try XCTUnwrap(context.makeImage())
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, image, nil); XCTAssertTrue(CGImageDestinationFinalize(target))
    return (root, url)
  }
  private func pixels(_ result: RenderedResult) throws -> [UInt8] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(result.data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    data.withUnsafeMutableBytes { bytes in
      let ctx = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return data
  }
  func testRenderingCacheExposureGeometryAndSourceIntegrity() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let originalBytes = try Data(contentsOf: url), id = UUID()
    let reference = OriginalReference(assetID: id, url: url)
    let renderer = CoreImageRenderer(); var recipe = EditRecipe.neutral(assetID: id)
    let output = RenderSpecification(maxDimension: 1000, format: "png")
    let neutral = try await renderer.render(original: reference, recipe: recipe, output: output)
    let repeatRender = try await renderer.render(original: reference, recipe: recipe, output: output)
    XCTAssertEqual(neutral.data, repeatRender.data)
    let count = await renderer.renderCount; XCTAssertEqual(count, 1)
    recipe.exposure = 1
    // Same revision with changed values must not hit an old cache entry.
    let exposed = try await renderer.render(original: reference, recipe: recipe, output: output)
    let before = try pixels(neutral), after = try pixels(exposed)
    XCTAssertGreaterThan(after[100 * 4], before[100 * 4])
    recipe.crop = EditRecipeCrop(x: 0.25, y: 0.25, width: 0.5, height: 0.5); recipe.rotation = 90
    let cropped = try await renderer.render(original: reference, recipe: recipe, output: output)
    XCTAssertEqual(cropped.width, 96); XCTAssertEqual(cropped.height, 128)
    XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    let full = try XCTUnwrap(CGImageSourceCreateWithData(neutral.data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(full, 0, nil))
    XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
  }
  func testPreviewMatchesDownsampledFullOutputWithSharedRecipe() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), renderer = CoreImageRenderer()
    var recipe = EditRecipe.neutral(assetID: id); recipe.exposure = 0.75; recipe.contrast = 0.2
    recipe.saturation = 0.7; recipe.sharpness = 0.4; recipe.noiseReduction = 0.2
    let reference = OriginalReference(assetID: id, url: url)
    let full = try await renderer.render(original: reference, recipe: recipe, output: .init(maxDimension: 256, format: "png"))
    let preview = try await renderer.render(original: reference, recipe: recipe, output: .init(maxDimension: 128, format: "png"))
    let fullImage = try XCTUnwrap(CIImage(data: full.data))
    let ci = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!])
    let downsample = try XCTUnwrap(ci.pngRepresentation(of: fullImage.transformed(by: .init(scaleX: 0.5, y: 0.5)),
      format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
    let expected = try pixels(.init(data: downsample, width: 128, height: 96)), actual = try pixels(preview)
    XCTAssertEqual(actual.count, expected.count)
    let meanError = zip(actual, expected).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(actual.count)
    XCTAssertLessThan(meanError, 2.0, "Preview/full-image comparison in 8-bit sRGB")
  }
  func testInvalidVersionsParametersMissingOriginalAndCancellation() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), renderer = CoreImageRenderer(cacheLimit: 1)
    var recipe = EditRecipe.neutral(assetID: id); recipe.schemaVersion = 2
    do { _ = try await renderer.render(original: .init(assetID: id, url: url), recipe: recipe, output: .init(maxDimension: 128, format: "png")); XCTFail() } catch ContractError.unsupportedVersion(2) {} catch { XCTFail("\(error)") }
    recipe.schemaVersion = 1; recipe.crop.width = 0; XCTAssertThrowsError(try recipe.validate())
    recipe = .neutral(assetID: id)
    let reference = OriginalReference(assetID: id, url: url)
    _ = try await renderer.render(original: reference, recipe: recipe, output: .init(maxDimension: 128, format: "jpeg"))
    let bytes = await renderer.cachedBytes; XCTAssertEqual(bytes, 0)
    let cancellationRecipe = recipe
    let task = Task { try await renderer.render(original: reference, recipe: cancellationRecipe, output: .init(maxDimension: 256, format: "tiff")) }
    task.cancel()
    do { _ = try await task.value; XCTFail() } catch is CancellationError {} catch { XCTFail("\(error)") }
    do { _ = try await renderer.render(original: .init(assetID: id, url: url, fingerprint: "changed"), recipe: recipe, output: .init(maxDimension: 128, format: "png")); XCTFail() } catch RenderFailure.changedOriginal {} catch { XCTFail("\(error)") }
    try FileManager.default.removeItem(at: url)
    do { _ = try await renderer.render(original: reference, recipe: recipe, output: .init(maxDimension: 128, format: "png")); XCTFail() } catch RenderFailure.missingOriginal {} catch { XCTFail("\(error)") }
  }
  @MainActor func testHistoryAutosaveGestureReopenUndoRedoAndAssetIsolation() throws {
    let (root, _) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let db = root.appendingPathComponent("Library.store"), a = UUID(), b = UUID()
    var final: EditRecipe!
    do {
      let store = try ProjectStore(container: ProjectStore.container(url: db))
      let project = try store.create(title: "Edit test")
      for id in [a, b] { try store.add(PhotoRecord(id: id, fingerprint: id.uuidString, filename: "generated.png", mediaType: "public.png", width: 256, height: 192, byteCount: 1), to: project.id) }
      var history = EditHistory(assetID: a); history.beginGesture()
      for value in [0.1, 0.5, 1.0] { var recipe = history.current; recipe.exposure = value; try history.set(recipe); try store.saveEdits(history) }
      // Persisted in-progress gestures are recovered as one completed undo operation on reopen.
      final = history.current
    }
    let reopened = try ProjectStore(container: ProjectStore.container(url: db))
    var history = try reopened.edits(for: a)
    XCTAssertEqual(history.current, final); XCTAssertEqual(history.undo.count, 1)
    history.undoEdit(); XCTAssertEqual(history.current.exposure, 0)
    history.redoEdit(); XCTAssertTrue(history.current.hasSameAdjustments(as: final))
    history.undoEdit(); var changed = history.current; changed.contrast = 0.5; try history.set(changed)
    XCTAssertTrue(history.redo.isEmpty)
    try reopened.saveEdits(history)
    XCTAssertEqual(try reopened.edits(for: b).current.exposure, 0)
    XCTAssertThrowsError(try history.set(.neutral(assetID: b)))
  }
  @MainActor func testMissingOriginalRetainsEditsAndRetryRecovers() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let source = try Data(contentsOf: url)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Recovery")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "gradient.png",
      mediaType: "public.png", width: 256, height: 192, byteCount: Int64(source.count), bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    try FileManager.default.removeItem(at: url)
    let editor = EditController(store: store, locations: LibraryLocations(root: root))
    editor.open(record); editor.set(\.exposure, value: 0.5); await editor.waitForPreview()
    XCTAssertNotNil(editor.renderError); XCTAssertTrue(editor.isSaved)
    XCTAssertEqual(try store.edits(for: record.id).current.exposure, 0.5)
    try source.write(to: url)
    editor.retry(); await editor.waitForPreview()
    XCTAssertNil(editor.renderError); XCTAssertNotNil(editor.previewImage)
    XCTAssertEqual(try Data(contentsOf: url), source)
  }
  @MainActor func testUnsupportedPersistedRecipeIsNotOverwritten() throws {
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let id = UUID(), history = EditHistory(assetID: UUID())
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(history)) as? [String: Any])
    var recipe = try XCTUnwrap(object["current"] as? [String: Any]); recipe["schemaVersion"] = 99
    object["current"] = recipe
    let original = try JSONSerialization.data(withJSONObject: object)
    let saved = LocalEditState(assetID: id, journal: original); store.context.insert(saved); try store.context.save()
    XCTAssertThrowsError(try store.edits(for: id))
    XCTAssertEqual(saved.journal, original)
  }
  @MainActor func testPhaseThreeLibraryMigratesWithAnnotationsAndCollections() throws {
    let (root, _) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("Library.store"), id = UUID(), projectID = UUID()
    do {
      let schema = Schema([LocalProject.self, LocalPhoto.self, LocalPhotoMembership.self, LocalBrowsingState.self,
        LocalPhotoAnnotation.self, LocalLibraryQuery.self, LocalCollection.self, LocalCollectionItem.self, LocalProjectPresentation.self])
      let old = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
      let context = ModelContext(old)
      context.insert(LocalProject(id: projectID, title: "Preserved project"))
      context.insert(LocalPhoto(PhotoRecord(id: id, fingerprint: "migration", filename: "photo.jpg", mediaType: "public.jpeg", width: 256, height: 192, byteCount: 1), projectID: projectID))
      let annotation = LocalPhotoAnnotation(photoID: id); annotation.rating = 5; context.insert(annotation)
      let collection = LocalCollection(projectID: projectID, title: "Selects", position: 0)
      collection.items = [LocalCollectionItem(photoID: id, collection: collection)]; context.insert(collection); try context.save()
    }
    let upgraded = try ProjectStore(container: ProjectStore.container(url: url))
    XCTAssertEqual(try upgraded.photos(in: projectID).first?.rating, 5)
    XCTAssertEqual(try upgraded.collections(in: projectID).first?.photoIDs, [id])
    var history = try upgraded.edits(for: id); var recipe = history.current; recipe.exposure = 1
    try history.set(recipe); try upgraded.saveEdits(history)
    XCTAssertEqual(try upgraded.edits(for: id).current.exposure, 1)
  }
  @MainActor func testSupersededRenderCannotReplaceNewerEdit() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let locations = LibraryLocations(root: root)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Concurrency")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "gradient.png",
      mediaType: "public.png", width: 256, height: 192, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let editor = EditController(store: store, locations: locations, renderer: DelayedRenderer())
    editor.open(record)
    try await Task.sleep(for: .milliseconds(160))
    editor.set(\.exposure, value: 1)
    await editor.waitForPreview()
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertEqual(editor.preview?.data, Data("1.0".utf8))
    XCTAssertEqual(try store.edits(for: record.id).current.exposure, 1)
  }
}
private actor DelayedRenderer: PhotoRenderer {
  func render(original: OriginalReference, recipe: EditRecipe, output: RenderSpecification) async throws -> RenderedResult {
    // Deliberately ignores cancellation, like a noninterruptible decoder/GPU operation.
    let delay = recipe.exposure == 0 ? 350 : 10
    await Task.detached { try? await Task.sleep(for: .milliseconds(delay)) }.value
    return RenderedResult(data: Data(String(recipe.exposure).utf8), width: 1, height: 1)
  }
}
