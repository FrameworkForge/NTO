import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import NTOFoundation

/// Phase 07: export naming, conflicts, rendered output, metadata policy, and original safety.
final class ExportTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
  /// A 64×32 JPEG with orientation 6 (so it displays 32×64), camera EXIF and GPS.
  private func cameraJPEG(in root: URL) throws -> URL {
    let url = root.appendingPathComponent("IMG_0001.jpg")
    let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    context.setFillColor(CGColor(colorSpace: srgb, components: [0.5, 0.5, 0.5, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
    context.setFillColor(CGColor(colorSpace: srgb, components: [0.9, 0.2, 0.2, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: 16, height: 32))
    let properties: [CFString: Any] = [
      kCGImagePropertyOrientation: 6,
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "NTO", kCGImagePropertyTIFFModel: "TestCam"],
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifFNumber: 2.8, kCGImagePropertyExifISOSpeedRatings: [400]],
      kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 0.12, kCGImagePropertyGPSLongitudeRef: "W"],
    ]
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, try XCTUnwrap(context.makeImage()), properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(target))
    return url
  }
  private func properties(_ url: URL) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }
  /// XMP values as strings: plain strings, language alternatives (dc:description) and bags (dc:subject) all flatten.
  private func xmp(_ url: URL, _ path: String) -> [String]? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
      let tag = CGImageMetadataCopyTagWithPath(metadata, nil, path as CFString) else { return nil }
    let value = CGImageMetadataTagCopyValue(tag)
    if let text = value as? String { return [text] }
    if let tags = value as? [CGImageMetadataTag] { return tags.compactMap { CGImageMetadataTagCopyValue($0) as? String } }
    if let strings = value as? [String] { return strings }
    return nil
  }
  @MainActor private func outcomes(_ exporter: ExportController) -> String {
    exporter.items.map { "\($0.filename): \(String(describing: $0.outcome))" }.joined(separator: " | ")
  }
  private func pixels(_ url: URL) throws -> [UInt8] {
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    data.withUnsafeMutableBytes { bytes in
      let ctx = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return data
  }

  func testFilenameTemplatesDatesSanitisationAndConflictPolicies() {
    let photo = PhotoRecord(id: UUID(), fingerprint: "f", filename: "IMG_0042.CR2", mediaType: "public.camera-raw-image",
      width: 10, height: 10, byteCount: 1, importedAt: Date(timeIntervalSince1970: 0), capturedAt: "2026:09:13 10:00:00", rating: 4)
    XCTAssertEqual(ExportNaming.filename(template: "{name}", photo: photo, projectTitle: "Wedding", index: 3, count: 120, format: .jpeg), "IMG_0042.jpg")
    XCTAssertEqual(ExportNaming.filename(template: "{project}-{index}", photo: photo, projectTitle: "Wedding", index: 3, count: 120, format: .tiff), "Wedding-003.tif")
    XCTAssertEqual(ExportNaming.filename(template: "{date} {name} r{rating}", photo: photo, projectTitle: "", index: 1, count: 1, format: .jpeg), "2026-09-13 IMG_0042 r4.jpg")
    XCTAssertEqual(ExportNaming.filename(template: "   ", photo: photo, projectTitle: "", index: 1, count: 1, format: .jpeg), "IMG_0042.jpg", "Blank template falls back to the original name")
    XCTAssertEqual(ExportNaming.filename(template: "../{name}:v1", photo: photo, projectTitle: "", index: 1, count: 1, format: .jpeg), "-IMG_0042-v1.jpg", "Path separators and colons cannot escape the folder")
    XCTAssertEqual(ExportNaming.filename(template: "{project}", photo: photo, projectTitle: "a/b", index: 1, count: 1, format: .jpeg), "a-b.jpg")
    var undated = photo; undated.capturedAt = nil
    XCTAssertEqual(ExportNaming.filename(template: "{date}", photo: undated, projectTitle: "", index: 1, count: 1, format: .jpeg), "1970-01-01.jpg")

    let folder = URL(fileURLWithPath: "/tmp/export")
    let existing: Set<String> = ["a.jpg", "a-1.jpg"]
    let exists: (URL) -> Bool = { existing.contains($0.lastPathComponent) }
    let fresh = folder.appendingPathComponent("b.jpg"), taken = folder.appendingPathComponent("a.jpg")
    XCTAssertEqual(ExportNaming.resolve(fresh, policy: .skip, exists: exists), fresh)
    XCTAssertNil(ExportNaming.resolve(taken, policy: .skip, exists: exists))
    XCTAssertEqual(ExportNaming.resolve(taken, policy: .replace, exists: exists), taken)
    XCTAssertEqual(ExportNaming.resolve(taken, policy: .keepBoth, exists: exists)?.lastPathComponent, "a-2.jpg")
  }

  @MainActor func testExportRendersEditsAppliesSizeProfileMetadataPolicyAndConflictsWithoutTouchingOriginals() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try cameraJPEG(in: root)
    let originalBytes = try Data(contentsOf: original)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Studio test")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(original), filename: "IMG_0001.jpg",
      mediaType: "public.jpeg", width: 32, height: 64, byteCount: Int64(originalBytes.count), bookmark: try PhotoImportWorker.bookmark(original))
    try store.add(record, to: project.id)
    try store.annotate([record.id], caption: "Morning light", keywords: ["street", "portrait"])
    var history = try store.edits(for: record.id); var recipe = history.current; recipe.exposure = 1
    try history.set(recipe); try store.saveEdits(history)
    let photos = try store.photos(in: project.id)
    let locations = LibraryLocations(root: root)
    let exporter = ExportController(store: store, locations: locations)
    let destination = root.appendingPathComponent("Exports")

    var spec = ExportSpecification()
    spec.metadata = .camera; spec.includeLocation = false; spec.filenameTemplate = "{project}-{index}"; spec.quality = 0.9
    exporter.start(spec, photos: photos, projectTitle: "Studio test", destination: destination)
    XCTAssertTrue(exporter.isRunning)
    await exporter.waitForCompletion()
    XCTAssertFalse(exporter.isRunning); XCTAssertEqual(exporter.exportedCount, 1); XCTAssertEqual(exporter.summary, "1 exported.")
    let file = destination.appendingPathComponent("Studio test-1.jpg")
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    let props = try properties(file)
    XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 32, "Orientation is baked in: the export is upright")
    XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 64)
    XCTAssertEqual(props[kCGImagePropertyProfileName] as? String, "sRGB IEC61966-2.1", "Embedded sRGB profile")
    XCTAssertTrue((props[kCGImagePropertyOrientation] as? Int ?? 1) == 1, "No stale orientation tag")
    let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    XCTAssertEqual(tiff?[kCGImagePropertyTIFFMake] as? String, "NTO", "Camera policy carries capture metadata")
    XCTAssertNil(props[kCGImagePropertyGPSDictionary], "Location is excluded unless requested")
    XCTAssertEqual(xmp(file, "dc:description"), ["Morning light"])
    XCTAssertEqual(Set(xmp(file, "dc:subject") ?? []), ["street", "portrait"])
    // Pixels equal the renderer's own output for the same recipe: the writer copies without re-encoding.
    let reference = OriginalReference(assetID: record.id, url: original, fingerprint: record.fingerprint)
    let rendered = try await CoreImageRenderer().render(original: reference, recipe: history.current, output: spec.renderSpecification)
    let direct = root.appendingPathComponent("direct.jpg"); try rendered.data.write(to: direct)
    XCTAssertEqual(try pixels(file), try pixels(direct))
    let exportedPixels = try pixels(file)
    XCTAssertGreaterThan(Int(exportedPixels[(32 * 32 + 16) * 4]), 150, "Exposure +1 brightened the mid grey")

    // Skip policy leaves the existing file alone and reports it.
    exporter.start(spec, photos: photos, projectTitle: "Studio test", destination: destination)
    await exporter.waitForCompletion()
    XCTAssertEqual(exporter.skipped.count, 1); XCTAssertEqual(exporter.summary, "0 exported, 1 skipped.")

    // Keep both adds a number; location included on request; descriptive policy strips camera data.
    spec.conflicts = .keepBoth; spec.includeLocation = true
    exporter.start(spec, photos: photos, projectTitle: "Studio test", destination: destination)
    await exporter.waitForCompletion()
    XCTAssertEqual(exporter.exportedCount, 1, outcomes(exporter))
    let second = destination.appendingPathComponent("Studio test-1-1.jpg")
    XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    XCTAssertNotNil(try properties(second)[kCGImagePropertyGPSDictionary])

    spec.metadata = .descriptive; spec.conflicts = .replace; spec.format = .tiff; spec.sizing = .fit(maxDimension: 40)
    exporter.start(spec, photos: photos, projectTitle: "Studio test", destination: destination)
    await exporter.waitForCompletion()
    XCTAssertEqual(exporter.exportedCount, 1, outcomes(exporter))
    let tiffFile = destination.appendingPathComponent("Studio test-1.tif")
    let tiffProps = try properties(tiffFile)
    XCTAssertEqual(tiffProps[kCGImagePropertyPixelHeight] as? Int, 40, "Fit resizes the longest edge")
    XCTAssertEqual(tiffProps[kCGImagePropertyPixelWidth] as? Int, 20)
    XCTAssertNil((tiffProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake], "Descriptive policy carries no camera data")
    XCTAssertEqual(xmp(tiffFile, "dc:description"), ["Morning light"], outcomes(exporter))

    spec.metadata = .none; spec.format = .jpeg; spec.sizing = .original; spec.quality = 0.5
    exporter.start(spec, photos: photos, projectTitle: "Studio test", destination: destination)
    await exporter.waitForCompletion()
    XCTAssertEqual(exporter.exportedCount, 1, outcomes(exporter))
    let replaced = try properties(file)
    XCTAssertNil(xmp(file, "dc:description"), "None policy writes no descriptive metadata")
    XCTAssertNil((replaced[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake])
    XCTAssertEqual(replaced[kCGImagePropertyPixelWidth] as? Int, 32, "Original size never upscales or resizes")

    XCTAssertEqual(try Data(contentsOf: original), originalBytes, "The original is untouched")
    XCTAssertEqual(try store.edits(for: record.id).current.exposure, 1, "Saved edits are untouched")
  }

  @MainActor func testExportReportsMissingOriginalsAndStopsOnCancel() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Broken")
    let vanishing = try cameraJPEG(in: root)
    let bookmark = try PhotoImportWorker.bookmark(vanishing)
    try FileManager.default.removeItem(at: vanishing)
    let missing = PhotoRecord(id: UUID(), fingerprint: "gone", filename: "gone.jpg", mediaType: "public.jpeg", width: 8, height: 8, byteCount: 1,
      bookmark: bookmark)
    try store.add(missing, to: project.id)
    let exporter = ExportController(store: store, locations: LibraryLocations(root: root))
    let destination = root.appendingPathComponent("Out")
    exporter.start(ExportSpecification(), photos: try store.photos(in: project.id), projectTitle: "Broken", destination: destination)
    await exporter.waitForCompletion()
    XCTAssertEqual(exporter.failures.count, 1)
    if case .failed(let message) = exporter.failures[0].outcome { XCTAssertTrue(message.contains("original"), message) } else { XCTFail() }
    XCTAssertEqual(exporter.summary, "0 exported, 1 failed.")

    let original = try cameraJPEG(in: root)
    var many: [PhotoRecord] = []
    for index in 0..<20 {
      let record = PhotoRecord(id: UUID(), fingerprint: "\(index)", filename: "f\(index).jpg", mediaType: "public.jpeg", width: 32, height: 64, byteCount: 1,
        bookmark: try PhotoImportWorker.bookmark(original))
      try store.add(record, to: project.id); many.append(record)
    }
    exporter.start(ExportSpecification(), photos: many, projectTitle: "Broken", destination: destination)
    exporter.cancel()
    await exporter.waitForCompletion()
    XCTAssertFalse(exporter.isRunning)
    XCTAssertLessThan(exporter.completed, 20)
    XCTAssertTrue(exporter.summary?.hasPrefix("Export stopped") == true, exporter.summary ?? "")
  }
}
