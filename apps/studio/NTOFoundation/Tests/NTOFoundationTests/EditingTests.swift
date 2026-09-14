import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import NTOFoundation

/// Phase 05 controls: grouped resets, white balance, quarter turns and crop clamping through the controller and renderer.
final class EditingTests: XCTestCase {
  private func fixture() throws -> (URL, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("card.png")
    let context = try XCTUnwrap(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
    let image = try XCTUnwrap(context.makeImage())
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, image, nil); XCTAssertTrue(CGImageDestinationFinalize(target))
    return (root, url)
  }
  private func pixel(_ result: RenderedResult, x: Int, y: Int) throws -> (r: UInt8, g: UInt8, b: UInt8) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(result.data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    data.withUnsafeMutableBytes { bytes in
      let ctx = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    let offset = (y * image.width + x) * 4
    return (data[offset], data[offset + 1], data[offset + 2])
  }

  func testRecipeGroupResetRotationWrapAndCropClamping() {
    let id = UUID()
    var recipe = EditRecipe.neutral(assetID: id)
    recipe.exposure = 1; recipe.contrast = 0.3; recipe.saturation = 1.4; recipe.temperature = 4200; recipe.tint = 10
    recipe.sharpness = 0.5; recipe.noiseReduction = 0.2; recipe.rotation = 12; recipe.crop = EditRecipeCrop(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    for group in EditGroup.allCases { XCTAssertFalse(recipe.isNeutral(group), group.rawValue) }
    var light = recipe; light.reset(.light)
    XCTAssertEqual(light.exposure, 0); XCTAssertEqual(light.contrast, 0); XCTAssertEqual(light.saturation, 1.4)
    XCTAssertTrue(light.isNeutral(.light)); XCTAssertFalse(light.isNeutral(.colour))
    var colour = recipe; colour.reset(.colour)
    XCTAssertNil(colour.temperature); XCTAssertEqual(colour.tint, 0); XCTAssertEqual(colour.saturation, 1); XCTAssertEqual(colour.exposure, 1)
    var geometry = recipe; geometry.reset(.geometry)
    XCTAssertEqual(geometry.crop, EditRecipeCrop(x: 0, y: 0, width: 1, height: 1)); XCTAssertEqual(geometry.rotation, 0)
    XCTAssertEqual(geometry.sharpness, 0.5)

    XCTAssertEqual(EditRecipe.normalizedRotation(270), -90)
    XCTAssertEqual(EditRecipe.normalizedRotation(-270), 90)
    XCTAssertEqual(EditRecipe.normalizedRotation(180), 180)
    XCTAssertEqual(EditRecipe.normalizedRotation(-180), 180)
    XCTAssertEqual(EditRecipe.normalizedRotation(360), 0)
    XCTAssertEqual(EditRecipe.normalizedRotation(.nan), 0)

    XCTAssertEqual(EditRecipe.clampedCrop(EditRecipeCrop(x: 0.8, y: -1, width: 0.5, height: 2)), EditRecipeCrop(x: 0.5, y: 0, width: 0.5, height: 1))
    XCTAssertEqual(EditRecipe.clampedCrop(EditRecipeCrop(x: 0, y: 0, width: 0, height: 0)).width, 0.01)
    XCTAssertEqual(EditRecipe.clampedCrop(EditRecipeCrop(x: .nan, y: 0, width: 0.5, height: 0.5)), EditRecipeCrop(x: 0, y: 0, width: 1, height: 1))
    var clamped = recipe; clamped.crop = EditRecipe.clampedCrop(EditRecipeCrop(x: 0.8, y: -1, width: 0.5, height: 2))
    XCTAssertNoThrow(try clamped.validate())
  }

  @MainActor func testControllerGroupResetWhiteBalanceQuarterTurnsAndCropAreUndoableAndSaved() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Controls")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "card.png",
      mediaType: "public.png", width: 200, height: 100, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let editor = EditController(store: store, locations: LibraryLocations(root: root))
    editor.open(record)
    editor.set(\.exposure, value: 1); editor.set(\.contrast, value: 0.5); editor.set(\.saturation, value: 1.5)
    editor.reset(.light)
    var current = try XCTUnwrap(editor.history?.current)
    XCTAssertEqual(current.exposure, 0); XCTAssertEqual(current.contrast, 0); XCTAssertEqual(current.saturation, 1.5)
    XCTAssertEqual(editor.history?.undo.count, 4, "Group reset is one undo operation")
    editor.undo()
    XCTAssertEqual(editor.history?.current.exposure, 1); XCTAssertEqual(editor.history?.current.contrast, 0.5)
    editor.redo()

    editor.setTemperature(99_000)
    XCTAssertEqual(editor.history?.current.temperature, 50_000, "Temperature entry is clamped to the recipe range")
    editor.setTemperature(nil)
    XCTAssertNil(editor.history?.current.temperature)
    XCTAssertTrue(editor.isSaved)

    for _ in 0..<3 { editor.rotate(by: 90) }
    XCTAssertEqual(editor.history?.current.rotation, -90)
    editor.rotate(by: -90); editor.rotate(by: -90)
    XCTAssertEqual(editor.history?.current.rotation, 90)
    editor.setRotation(.infinity)
    XCTAssertEqual(editor.history?.current.rotation, 0)

    editor.setCrop(EditRecipeCrop(x: 0.9, y: 0.9, width: 0.5, height: 0.5))
    current = try XCTUnwrap(editor.history?.current)
    XCTAssertEqual(current.crop, EditRecipeCrop(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    XCTAssertNil(editor.saveError)
    editor.reset(.geometry)
    XCTAssertEqual(editor.history?.current.crop, EditRecipeCrop(x: 0, y: 0, width: 1, height: 1))
    XCTAssertEqual(editor.history?.current.saturation, 1.5, "Geometry reset leaves colour untouched")

    editor.isComparing = true
    let before = editor.history?.current
    editor.isComparing = false
    XCTAssertEqual(editor.history?.current, before, "Comparing never changes the recipe")

    await editor.waitForPreview()
    XCTAssertNil(editor.renderError)
    let reopened = try store.edits(for: record.id)
    XCTAssertEqual(reopened.current, editor.history?.current)
    XCTAssertEqual(reopened.current.saturation, 1.5)
    XCTAssertGreaterThan(reopened.undo.count, 4)
  }

  /// Six 32-pixel bands: sRGB greys 0.05, 0.25, 0.5, 0.75, 0.95 and a muted red.
  private func bands() throws -> (URL, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("bands.png")
    let context = try XCTUnwrap(CGContext(data: nil, width: 192, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    let colours: [(CGFloat, CGFloat, CGFloat)] = [(0.05, 0.05, 0.05), (0.25, 0.25, 0.25), (0.5, 0.5, 0.5), (0.75, 0.75, 0.75), (0.95, 0.95, 0.95), (0.6, 0.5, 0.5)]
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    for (index, colour) in colours.enumerated() {
      context.setFillColor(CGColor(colorSpace: srgb, components: [colour.0, colour.1, colour.2, 1])!)
      context.fill(CGRect(x: index * 32, y: 0, width: 32, height: 64))
    }
    let image = try XCTUnwrap(context.makeImage())
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, image, nil); XCTAssertTrue(CGImageDestinationFinalize(target))
    return (root, url)
  }

  func testTonalRangeAndVibranceRendering() async throws {
    let (root, url) = try bands(); defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), renderer = CoreImageRenderer()
    let reference = OriginalReference(assetID: id, url: url)
    let output = RenderSpecification(maxDimension: 192, format: "png")
    let band = { (index: Int) in (index * 32 + 16, 32) }
    func grey(_ recipe: EditRecipe, _ index: Int) async throws -> Int {
      let (x, y) = band(index); return Int(try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: x, y: y).r)
    }
    var recipe = EditRecipe.neutral(assetID: id)
    let neutral = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertEqual(neutral[2], 128, accuracy: 2)

    recipe.shadows = 1
    let lifted = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertGreaterThan(lifted[1], neutral[1] + 15, "Shadows +1 lifts the quarter tone")
    XCTAssertEqual(lifted[2], neutral[2], accuracy: 3, "Midtone stays pinned")
    XCTAssertEqual(lifted[4], neutral[4], accuracy: 3, "Near-white is unaffected by shadows")

    recipe = .neutral(assetID: id); recipe.highlights = -1
    let recovered = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertLessThan(recovered[3], neutral[3] - 15, "Highlights −1 darkens the three-quarter tone")
    XCTAssertEqual(recovered[2], neutral[2], accuracy: 3)
    XCTAssertEqual(recovered[1], neutral[1], accuracy: 3, "Quarter tone is unaffected by highlights")

    recipe = .neutral(assetID: id); recipe.whites = 1
    let brightWhites = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertEqual(brightWhites[4], 255, accuracy: 1, "Whites +1 pushes 0.95 to clipping")
    XCTAssertEqual(brightWhites[2], neutral[2], accuracy: 3)

    recipe = .neutral(assetID: id); recipe.blacks = -1
    let crushed = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertEqual(crushed[0], 0, accuracy: 1, "Blacks −1 pushes 0.05 to black")
    recipe.blacks = 1
    let liftedBlacks = try await (0..<5).asyncMap { try await grey(recipe, $0) }
    XCTAssertGreaterThan(liftedBlacks[0], neutral[0] + 15, "Blacks +1 lifts near-black")
    XCTAssertEqual(liftedBlacks[2], neutral[2], accuracy: 3)

    recipe = .neutral(assetID: id)
    let (cx, cy) = band(5)
    let muted = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: cx, y: cy)
    recipe.vibrance = 1
    let vivid = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: cx, y: cy)
    XCTAssertGreaterThan(Int(vivid.r) - Int(vivid.g), Int(muted.r) - Int(muted.g), "Vibrance +1 increases a muted colour's chroma")
    recipe.vibrance = 0; recipe.saturation = 1
    let stillNeutral = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: cx, y: cy)
    XCTAssertEqual(Int(stillNeutral.r), Int(muted.r), accuracy: 1)
  }

  func testRecipesSavedBeforeTonalFieldsDecodeAsNeutralAndReencodeCompletely() throws {
    let id = UUID()
    let legacy = """
      {"schemaVersion":1,"assetId":"\(id.uuidString)","revision":3,"exposure":0.5,"contrast":0,"saturation":1,
       "temperature":null,"tint":0,"sharpness":0,"noiseReduction":0,"crop":{"x":0,"y":0,"width":1,"height":1},"rotation":0}
      """
    let recipe = try JSONDecoder().decode(EditRecipe.self, from: Data(legacy.utf8))
    XCTAssertEqual(recipe.highlights, 0); XCTAssertEqual(recipe.shadows, 0); XCTAssertEqual(recipe.whites, 0)
    XCTAssertEqual(recipe.blacks, 0); XCTAssertEqual(recipe.vibrance, 0); XCTAssertEqual(recipe.exposure, 0.5)
    XCTAssertTrue(recipe.isNeutral(.light) == false, "Exposure keeps the Light group non-neutral")
    XCTAssertTrue(recipe.isNeutral(.colour))
    let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any])
    XCTAssertEqual(encoded["vibrance"] as? Double, 0)
    var invalid = recipe; invalid.vibrance = 1.5
    XCTAssertThrowsError(try invalid.validate())
    var history = EditHistory(assetID: id)
    var next = history.current; next.highlights = 0.5; next.shadows = -0.25; try history.set(next)
    XCTAssertEqual(history.current.highlights, 0.5)
    var reset = history.current; reset.reset(.light)
    XCTAssertEqual(reset.highlights, 0); XCTAssertEqual(reset.shadows, 0)
  }

  func testRasterWhiteBalanceAndQuarterTurnRendering() async throws {
    let (root, url) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), renderer = CoreImageRenderer()
    let reference = OriginalReference(assetID: id, url: url)
    let output = RenderSpecification(maxDimension: 200, format: "png")
    var recipe = EditRecipe.neutral(assetID: id)
    let neutral = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: 100, y: 50)
    recipe.temperature = 6500
    let d65 = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: 100, y: 50)
    XCTAssertEqual(Int(d65.r), Int(neutral.r), accuracy: 1, "6500 K with zero tint leaves a raster image unchanged")
    XCTAssertEqual(Int(d65.b), Int(neutral.b), accuracy: 1)
    recipe.temperature = 3200
    let cooled = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: 100, y: 50)
    XCTAssertLessThan(Int(cooled.r) - Int(cooled.b), Int(neutral.r) - Int(neutral.b),
      "A lower Kelvin declares a warmer scene neutral, which is corrected toward D65 and cools the image")
    recipe.temperature = 12000
    let warmed = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: 100, y: 50)
    XCTAssertGreaterThan(Int(warmed.r) - Int(warmed.b), Int(neutral.r) - Int(neutral.b), "A higher Kelvin warms the image")
    recipe.temperature = nil; recipe.tint = 100
    let tinted = try pixel(try await renderer.render(original: reference, recipe: recipe, output: output), x: 100, y: 50)
    XCTAssertNotEqual(tinted.g, neutral.g, "Tint alone still adjusts a raster image")
    recipe.tint = 0; recipe.rotation = 90
    let turned = try await renderer.render(original: reference, recipe: recipe, output: output)
    XCTAssertEqual(turned.width, 100); XCTAssertEqual(turned.height, 200)
    recipe.rotation = -90
    let counter = try await renderer.render(original: reference, recipe: recipe, output: output)
    XCTAssertEqual(counter.width, 100); XCTAssertEqual(counter.height, 200)
    recipe.rotation = 180
    let flipped = try await renderer.render(original: reference, recipe: recipe, output: output)
    XCTAssertEqual(flipped.width, 200); XCTAssertEqual(flipped.height, 100)
  }
}

extension Range where Bound == Int {
  func asyncMap<T>(_ transform: (Int) async throws -> T) async rethrows -> [T] {
    var values: [T] = []
    for index in self { values.append(try await transform(index)) }
    return values
  }
}
