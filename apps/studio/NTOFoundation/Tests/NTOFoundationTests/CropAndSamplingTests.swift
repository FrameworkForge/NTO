import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import NTOFoundation

/// Phase 05 completion: interactive crop geometry and session, white-balance eyedropper, 100% inspection.
final class CropAndSamplingTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
  /// 120×80 image: a warm cast over the whole frame, with a distinctly red patch at the top-left quarter.
  private func warmImage(in root: URL, cast: (CGFloat, CGFloat, CGFloat)) throws -> URL {
    let url = root.appendingPathComponent("warm.png")
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = try XCTUnwrap(CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(colorSpace: srgb, components: [cast.0, cast.1, cast.2, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
    context.setFillColor(CGColor(colorSpace: srgb, components: [0.9, 0.1, 0.1, 1])!)
    context.fill(CGRect(x: 0, y: 40, width: 60, height: 40))  // Core Graphics origin is bottom-left: this is the top-left quarter.
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, try XCTUnwrap(context.makeImage()), nil); XCTAssertTrue(CGImageDestinationFinalize(target))
    return url
  }
  private func pixel(_ data: Data, x: Int, y: Int) throws -> (Int, Int, Int) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      let ctx = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    let offset = (y * image.width + x) * 4
    return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
  }

  func testCropGeometryHandlesResizeAspectAndClamping() {
    let full = EditRecipeCrop(x: 0, y: 0, width: 1, height: 1)
    let displayed = CropGeometry.fittedRect(imageSize: CGSize(width: 300, height: 200), in: CGSize(width: 600, height: 600))
    XCTAssertEqual(displayed, CGRect(x: 0, y: 100, width: 600, height: 400))
    let rect = CropGeometry.viewRect(EditRecipeCrop(x: 0.25, y: 0.25, width: 0.5, height: 0.5), in: displayed)
    XCTAssertEqual(rect, CGRect(x: 150, y: 200, width: 300, height: 200))
    XCTAssertEqual(CropGeometry.handle(at: CGPoint(x: 152, y: 202), rect: rect, tolerance: 12), .topLeft)
    XCTAssertEqual(CropGeometry.handle(at: CGPoint(x: 300, y: 400), rect: rect, tolerance: 12), .bottom)
    XCTAssertEqual(CropGeometry.handle(at: CGPoint(x: 300, y: 300), rect: rect, tolerance: 12), .move)
    XCTAssertEqual(CropGeometry.handle(at: CGPoint(x: 20, y: 20), rect: rect, tolerance: 12), .none)
    XCTAssertEqual(CropGeometry.handle(at: CGPoint(x: 300, y: 500), rect: rect, tolerance: 12), .none)

    let quarter = EditRecipeCrop(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let dragged = CropGeometry.resize(quarter, handle: .bottomRight, dx: 0.1, dy: -0.1, heightFactor: nil)
    XCTAssertEqual(dragged, EditRecipeCrop(x: 0.25, y: 0.25, width: 0.6, height: 0.4))
    let moved = CropGeometry.resize(quarter, handle: .move, dx: 0.5, dy: -0.5, heightFactor: nil)
    XCTAssertEqual(moved, EditRecipeCrop(x: 0.5, y: 0, width: 0.5, height: 0.5), "Moving clamps inside the image")
    let collapsed = CropGeometry.resize(quarter, handle: .left, dx: 0.9, dy: 0, heightFactor: nil)
    XCTAssertEqual(collapsed.width, CropGeometry.minimumSize, accuracy: 1e-9, "An edge cannot cross the opposite edge")

    // Square on a 300×200 image: normalized height = width × 1.5.
    let k = try! XCTUnwrap(CropGeometry.heightFactor(aspect: .square, portrait: false, imageSize: CGSize(width: 300, height: 200)))
    XCTAssertEqual(k, 1.5)
    let square = CropGeometry.resize(full, handle: .bottomRight, dx: -0.5, dy: 0, heightFactor: k)
    XCTAssertEqual(square.width * 300, square.height * 200, accuracy: 1e-6, "Corner drags keep the pixel aspect")
    XCTAssertEqual(square.x, 0); XCTAssertEqual(square.y, 0)
    let fitted = CropGeometry.fitted(aspect: k, within: full)
    XCTAssertEqual(fitted, EditRecipeCrop(x: (1 - 2.0 / 3.0) / 2, y: 0, width: 2.0 / 3.0, height: 1), "Largest centred square")
    let portrait = try! XCTUnwrap(CropGeometry.heightFactor(aspect: .threeTwo, portrait: true, imageSize: CGSize(width: 300, height: 200)))
    XCTAssertEqual(portrait, 1.5 / (2.0 / 3.0), accuracy: 1e-9)
    XCTAssertNil(CropGeometry.heightFactor(aspect: .free, portrait: false, imageSize: CGSize(width: 300, height: 200)))

    let size = CGSize(width: 1000, height: 500)
    let centre = CropGeometry.originalPoint(fromDisplayed: CGPoint(x: 0.5, y: 0.5), crop: quarter, rotation: 37, imageSize: size)
    XCTAssertEqual(centre.x, 0.5, accuracy: 1e-9); XCTAssertEqual(centre.y, 0.5, accuracy: 1e-9)
    let unrotated = CropGeometry.originalPoint(fromDisplayed: CGPoint(x: 0, y: 0), crop: quarter, rotation: 0, imageSize: size)
    XCTAssertEqual(unrotated.x, 0.25, accuracy: 1e-9); XCTAssertEqual(unrotated.y, 0.25, accuracy: 1e-9)
    // Rotated 90° clockwise, the displayed top-left corner is the crop's bottom-left corner.
    let turned = CropGeometry.originalPoint(fromDisplayed: CGPoint(x: 0, y: 0), crop: quarter, rotation: 90, imageSize: size)
    XCTAssertEqual(turned.x, 0.25, accuracy: 1e-6); XCTAssertEqual(turned.y, 0.75, accuracy: 1e-6)
  }

  @MainActor func testCropSessionPreviewsUncroppedCommitsOnceAndCancelRestores() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = try warmImage(in: root, cast: (0.5, 0.5, 0.5))
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Crop")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "warm.png", mediaType: "public.png",
      width: 120, height: 80, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let editor = EditController(store: store, locations: LibraryLocations(root: root), previews: PhotoPreviews(locations: LibraryLocations(root: root)))
    editor.activate(record)
    editor.setCrop(EditRecipeCrop(x: 0.25, y: 0.25, width: 0.5, height: 0.5)); editor.setRotation(90)
    let undoBefore = editor.history?.undo.count ?? 0
    editor.beginCrop()
    XCTAssertEqual(editor.previewRecipe?.crop, EditRecipeCrop(x: 0, y: 0, width: 1, height: 1), "Crop session previews the whole photograph")
    XCTAssertEqual(editor.previewRecipe?.rotation, 0)
    XCTAssertEqual(editor.history?.current.crop.width, 0.5, "The recipe itself is untouched while cropping")
    editor.updateCrop(EditRecipeCrop(x: 0.1, y: 0.1, width: 0.8, height: 0.6))
    editor.setCropAspect(.square, portrait: false)
    let pending = try XCTUnwrap(editor.cropSession?.pending)
    XCTAssertEqual(pending.width * 120, pending.height * 80, accuracy: 1e-6, "Aspect presets fit the pending rectangle")
    editor.cancelCrop()
    XCTAssertNil(editor.cropSession)
    XCTAssertEqual(editor.history?.current.crop, EditRecipeCrop(x: 0.25, y: 0.25, width: 0.5, height: 0.5), "Escape restores the previous crop")
    XCTAssertEqual(editor.history?.undo.count, undoBefore)

    editor.beginCrop()
    editor.updateCrop(EditRecipeCrop(x: 0.9, y: 0.9, width: 0.5, height: 0.5))
    editor.commitCrop()
    XCTAssertNil(editor.cropSession)
    XCTAssertEqual(editor.history?.current.crop, EditRecipeCrop(x: 0.5, y: 0.5, width: 0.5, height: 0.5), "Return commits a clamped crop")
    XCTAssertEqual(editor.history?.undo.count, undoBefore + 1, "One undo step per committed crop")
    XCTAssertEqual(editor.history?.current.rotation, 90, "Rotation survives the crop session")
    editor.beginCrop(); editor.commitCrop()
    XCTAssertEqual(editor.history?.undo.count, undoBefore + 1, "Committing an unchanged crop adds no history")
    await editor.waitForPreview()
    XCTAssertEqual(editor.previewRecipe, editor.history?.current)
  }

  func testEyedropperSolvesTemperatureAndTintThatNeutraliseTheSampledColour() throws {
    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .outputColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, .workingFormat: CIFormat.RGBAf, .useSoftwareRenderer: true])
    for cast in [LinearRGB(r: 0.55, g: 0.45, b: 0.32), LinearRGB(r: 0.30, g: 0.42, b: 0.60), LinearRGB(r: 0.40, g: 0.40, b: 0.40)] {
      let solution = WhiteBalanceSampler.neutral(forLinear: cast)
      let corrected = WhiteBalanceSampler.corrected(cast, temperature: solution.temperature, tint: solution.tint, context: context)
      XCTAssertLessThan(corrected.chroma, 0.03, "\(cast) → \(solution) leaves chroma \(corrected.chroma)")
      XCTAssertTrue(WhiteBalanceSampler.temperatureRange.contains(solution.temperature))
      XCTAssertTrue(WhiteBalanceSampler.tintRange.contains(solution.tint))
    }
    let grey = WhiteBalanceSampler.neutral(forLinear: LinearRGB(r: 0.4, g: 0.4, b: 0.4))
    XCTAssertEqual(grey.temperature, 6500, accuracy: 300, "A neutral sample stays near D65"); XCTAssertEqual(grey.tint, 0, accuracy: 10)
  }

  @MainActor func testEyedropperOnThePreviewSetsWhiteBalanceAsOneUndoStepAndRendersNeutral() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = try warmImage(in: root, cast: (0.72, 0.62, 0.48))
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Eyedropper")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "warm.png", mediaType: "public.png",
      width: 120, height: 80, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let locations = LibraryLocations(root: root)
    let editor = EditController(store: store, locations: locations, previews: PhotoPreviews(locations: locations))
    editor.activate(record)
    await editor.waitForPreview()
    let undoBefore = editor.history?.undo.count ?? 0
    editor.isSamplingWhiteBalance = true
    await editor.sampleWhiteBalance(at: CGPoint(x: 0.75, y: 0.75))  // the warm area, away from the red patch
    XCTAssertFalse(editor.isSamplingWhiteBalance); XCTAssertNil(editor.sampleError)
    let recipe = try XCTUnwrap(editor.history?.current)
    XCTAssertNotNil(recipe.temperature); XCTAssertEqual(editor.history?.undo.count, undoBefore + 1)
    let reference = OriginalReference(assetID: record.id, url: url, fingerprint: record.fingerprint)
    let rendered = try await CoreImageRenderer().render(original: reference, recipe: recipe, output: RenderSpecification(maxDimension: 120, format: "png"))
    let (r, g, b) = try pixel(rendered.data, x: 90, y: 60)
    XCTAssertLessThan(abs(r - g), 6, "Sampled area renders neutral: \(r),\(g),\(b)"); XCTAssertLessThan(abs(b - g), 6)
    let (pr, pg, pb) = try pixel(rendered.data, x: 30, y: 20)
    XCTAssertGreaterThan(pr, pg + 60, "A genuinely red patch stays red: \(pr),\(pg),\(pb)")
    await editor.waitForPreview()
  }

  @MainActor func testInspectionRendersTheEditedResultAtFullSize() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = try warmImage(in: root, cast: (0.5, 0.5, 0.5))
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Inspect")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "warm.png", mediaType: "public.png",
      width: 120, height: 80, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let editor = EditController(store: store, locations: LibraryLocations(root: root))
    editor.activate(record)
    editor.setCrop(EditRecipeCrop(x: 0, y: 0, width: 0.5, height: 1))
    editor.setInspecting(true)
    XCTAssertTrue(editor.isInspecting)
    await editor.waitForFullResolution()
    let image = try XCTUnwrap(editor.fullImage)
    XCTAssertEqual(image.width, 60); XCTAssertEqual(image.height, 80)
    editor.setRotation(90)
    await editor.waitForFullResolution()
    XCTAssertEqual(editor.fullImage?.width, 80, "Inspection follows recipe changes"); XCTAssertEqual(editor.fullImage?.height, 60)
    editor.setInspecting(false)
    XCTAssertNil(editor.fullImage)

    // Refinement after expensive interactions: no full render while a gesture is in progress, one when it ends.
    editor.setInspecting(true)
    await editor.waitForFullResolution()
    let before = editor.fullImage
    editor.beginGesture()
    editor.set(\.exposure, value: 0.5)
    editor.set(\.exposure, value: 0.8)
    XCTAssertTrue(editor.fullResolutionPending, "Full render is deferred during the gesture")
    XCTAssertFalse(editor.isRenderingFull)
    XCTAssertTrue(editor.fullImage === before, "The previous full image stays visible while dragging")
    editor.finishGesture()
    XCTAssertFalse(editor.fullResolutionPending)
    XCTAssertTrue(editor.isRenderingFull, "One full render starts when the gesture ends")
    await editor.waitForFullResolution()
    XCTAssertFalse(editor.fullImage === before)
    editor.setInspecting(false)
    editor.setInspecting(true); editor.beginCrop()
    XCTAssertFalse(editor.isInspecting, "Cropping leaves inspection")
    editor.cancelCrop()
    await editor.waitForPreview()
  }
}
