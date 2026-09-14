import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import NTOFoundation

/// Phase 06: portable presets, copy/paste subsets, and background sync with a defined revert.
final class PresetTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
  private func edited(_ id: UUID) -> EditRecipe {
    var recipe = EditRecipe.neutral(assetID: id)
    recipe.exposure = 0.7; recipe.contrast = 0.2; recipe.highlights = -0.3; recipe.shadows = 0.4
    recipe.temperature = 4800; recipe.tint = 12; recipe.vibrance = 0.3; recipe.saturation = 1.2
    recipe.sharpness = 0.5; recipe.noiseReduction = 0.1
    recipe.crop = EditRecipeCrop(x: 0.1, y: 0.2, width: 0.6, height: 0.5); recipe.rotation = 90
    return recipe
  }
  private func card(in root: URL) throws -> URL {
    let url = root.appendingPathComponent("card.png")
    let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [0.5, 0.5, 0.5, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
    let target = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(target, try XCTUnwrap(context.makeImage()), nil); XCTAssertTrue(CGImageDestinationFinalize(target))
    return url
  }

  func testSubsetsExcludeWhiteBalanceAndGeometryByDefaultAndRoundTripAsPortableJSON() throws {
    let source = edited(UUID())
    let safe = source.adjustments(for: EditParameter.safeDefaults)
    XCTAssertNil(safe[.temperature]); XCTAssertNil(safe[.tint]); XCTAssertNil(safe[.crop]); XCTAssertNil(safe[.rotation])
    XCTAssertEqual(safe[.exposure], .number(0.7)); XCTAssertEqual(safe.count, EditParameter.allCases.count - 4)

    var everything = source.adjustments(for: Set(EditParameter.allCases))
    XCTAssertEqual(everything[.crop], .crop(source.crop)); XCTAssertEqual(everything[.temperature], .number(4800))
    var asShot = source; asShot.temperature = nil
    everything[.temperature] = asShot.value(of: .temperature)
    XCTAssertEqual(everything[.temperature], .asShot)

    let preset = EditPreset(name: "Evening", adjustments: everything)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(preset)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let adjustments = try XCTUnwrap(json["adjustments"] as? [String: Any])
    XCTAssertTrue(adjustments["temperature"] is NSNull, "As-shot white balance is portable JSON null")
    XCTAssertEqual(adjustments["exposure"] as? Double, 0.7)
    XCTAssertNotNil(adjustments["crop"] as? [String: Any])
    XCTAssertEqual(json["formatVersion"] as? Int, 1)
    let decoded = try JSONDecoder().decode(EditPreset.self, from: data)
    XCTAssertEqual(decoded, preset)

    var target = EditRecipe.neutral(assetID: UUID()); target.crop = EditRecipeCrop(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
    try target.apply(safe)
    XCTAssertEqual(target.exposure, 0.7); XCTAssertEqual(target.vibrance, 0.3)
    XCTAssertEqual(target.crop, EditRecipeCrop(x: 0.3, y: 0.3, width: 0.4, height: 0.4), "Excluded crop is preserved")
    XCTAssertNil(target.temperature, "Excluded white balance is preserved")
    XCTAssertNoThrow(try target.validate())

    XCTAssertThrowsError(try target.apply([.crop: .number(1)])) { XCTAssertEqual($0 as? PresetError, .invalidValue(.crop)) }
    var future = json; future["formatVersion"] = 2
    XCTAssertThrowsError(try JSONDecoder().decode(EditPreset.self, from: JSONSerialization.data(withJSONObject: future)))
  }

  @MainActor func testPresetStoreSavesLoadsRenamesDeletesAndReportsUnreadableFiles() throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appendingPathComponent("Presets")
    let store = PresetStore(directory: directory)
    XCTAssertTrue(store.presets.isEmpty)
    XCTAssertThrowsError(try store.save(EditPreset(name: "  ", adjustments: [.exposure: .number(1)])))
    XCTAssertThrowsError(try store.save(EditPreset(name: "Empty", adjustments: [:])))
    let warm = try store.save(EditPreset(name: " Warm ", adjustments: [.temperature: .number(4000), .exposure: .number(0.3)]))
    let bright = try store.save(EditPreset(name: "Bright", adjustments: [.exposure: .number(1)]))
    XCTAssertEqual(warm.name, "Warm")
    XCTAssertEqual(store.presets.map(\.name), ["Bright", "Warm"])
    try Data("{not json".utf8).write(to: directory.appendingPathComponent("broken.json"))
    let reopened = PresetStore(directory: directory)
    XCTAssertEqual(reopened.presets, [bright, warm])
    XCTAssertEqual(reopened.issues.count, 1)
    try reopened.rename(bright.id, to: "Zesty")
    XCTAssertEqual(reopened.presets.map(\.name), ["Warm", "Zesty"])

    var recipe = EditRecipe.neutral(assetID: UUID()); try recipe.apply(warm.adjustments)
    try reopened.delete(warm.id)
    XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.url(for: warm.id).path))
    XCTAssertEqual(recipe.temperature, 4000, "Deleting a preset never alters recipes that used it")
    XCTAssertThrowsError(try reopened.delete(warm.id))

    let exported = root.appendingPathComponent("zesty.json")
    try reopened.export(bright.id, to: exported)
    let imported = try reopened.importPreset(from: exported)
    XCTAssertNotEqual(imported.id, bright.id, "Importing a preset with an existing id keeps both")
    XCTAssertEqual(imported.adjustments, bright.adjustments)
    XCTAssertEqual(reopened.presets.count, 2)
  }

  @MainActor func testControllerAppliesPresetAsOneUndoStepCopiesPastesAndPreviewsWithoutChangingRecipe() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = try card(in: root)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Presets")
    let record = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "card.png",
      mediaType: "public.png", width: 64, height: 32, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    try store.add(record, to: project.id)
    let editor = EditController(store: store, locations: LibraryLocations(root: root))
    editor.open(record)
    editor.setCrop(EditRecipeCrop(x: 0.2, y: 0.2, width: 0.5, height: 0.5))
    let preset = EditPreset(name: "Look", adjustments: [.exposure: .number(0.5), .contrast: .number(0.25), .vibrance: .number(0.4)])
    let undoBefore = editor.history?.undo.count ?? 0
    let recipeBefore = editor.history?.current
    editor.previewAdjustments(preset.adjustments)
    XCTAssertTrue(editor.isPreviewingAdjustments)
    XCTAssertEqual(editor.history?.current, recipeBefore, "Hover preview never touches the recipe")
    editor.clearAdjustmentPreview()
    XCTAssertNil(editor.adjustmentPreviewImage); XCTAssertFalse(editor.isPreviewingAdjustments)

    editor.apply(preset.adjustments)
    XCTAssertEqual(editor.history?.undo.count, undoBefore + 1, "A preset is one undo step")
    XCTAssertEqual(editor.history?.current.exposure, 0.5); XCTAssertEqual(editor.history?.current.vibrance, 0.4)
    XCTAssertEqual(editor.history?.current.crop, EditRecipeCrop(x: 0.2, y: 0.2, width: 0.5, height: 0.5))
    editor.undo()
    XCTAssertEqual(editor.history?.current.exposure, 0)
    editor.redo()

    editor.copy(EditParameter.safeDefaults)
    XCTAssertEqual(editor.copied?[.exposure], .number(0.5)); XCTAssertNil(editor.copied?[.crop])
    editor.reset()
    editor.paste()
    XCTAssertEqual(editor.history?.current.exposure, 0.5)
    XCTAssertEqual(editor.history?.current.crop, EditRecipeCrop(x: 0, y: 0, width: 1, height: 1), "Paste of a safe subset leaves the reset crop alone")
    editor.apply([.exposure: .number(9)])
    XCTAssertNotNil(editor.saveError, "Out-of-range preset values are refused with a message")
    XCTAssertEqual(editor.history?.current.exposure, 0.5)
    await editor.waitForPreview()
  }

  @MainActor func testBatchSyncPreservesExcludedValuesStaysResponsiveAndRevertsOnlyUnchangedPhotographs() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Event")
    var ids: [UUID] = []
    for index in 0..<100 {
      let record = PhotoRecord(id: UUID(), fingerprint: UUID().uuidString, filename: "frame-\(index).jpg", mediaType: "public.jpeg", width: 100, height: 60, byteCount: 1)
      try store.add(record, to: project.id); ids.append(record.id)
      if index % 2 == 0 {
        var history = try store.edits(for: record.id); var recipe = history.current
        recipe.crop = EditRecipeCrop(x: 0.1, y: 0.1, width: 0.5, height: 0.5); recipe.temperature = 3000
        try history.set(recipe); try store.saveEdits(history)
      }
    }
    let batch = BatchEditController(store: store)
    let adjustments: RecipeAdjustments = [.exposure: .number(0.6), .highlights: .number(-0.2), .temperature: .asShot]
    let started = Date()
    batch.sync(adjustments, to: ids.map { ($0, "frame") })
    XCTAssertTrue(batch.isRunning)
    XCTAssertLessThan(Date().timeIntervalSince(started), 0.5, "Starting a sync returns immediately")
    await batch.waitForCompletion()
    XCTAssertFalse(batch.isRunning); XCTAssertEqual(batch.completed, 100); XCTAssertTrue(batch.failures.isEmpty)
    XCTAssertEqual(batch.lastOutcomes.count, 100)
    for (index, id) in ids.enumerated() {
      let history = try store.edits(for: id)
      XCTAssertEqual(history.current.exposure, 0.6); XCTAssertEqual(history.current.highlights, -0.2)
      XCTAssertNil(history.current.temperature, "Explicitly included as-shot white balance applies")
      XCTAssertEqual(history.current.crop.width, index % 2 == 0 ? 0.5 : 1, "Excluded crop values are preserved")
      XCTAssertEqual(history.undo.count, index % 2 == 0 ? 2 : 1, "Each photograph gets exactly one undo step")
    }
    // A photograph edited after the sync is left alone by revert.
    var later = try store.edits(for: ids[7]); var changed = later.current; changed.contrast = 0.9
    try later.set(changed); try store.saveEdits(later)
    let report = batch.revertLast()
    XCTAssertEqual(report.reverted, 99); XCTAssertEqual(report.skipped, 1); XCTAssertTrue(report.failures.isEmpty)
    XCTAssertEqual(try store.edits(for: ids[0]).current.exposure, 0)
    XCTAssertEqual(try store.edits(for: ids[0]).current.temperature, 3000, "Revert restores the previous white balance")
    XCTAssertEqual(try store.edits(for: ids[7]).current.exposure, 0.6)
    XCTAssertEqual(try store.edits(for: ids[7]).current.contrast, 0.9)
    XCTAssertTrue(batch.lastOutcomes.isEmpty)

    // Syncing values already present makes no new history.
    batch.sync([.contrast: .number(0)], to: [(ids[1], "frame-1")])
    await batch.waitForCompletion()
    XCTAssertTrue(batch.lastOutcomes.isEmpty)
    XCTAssertEqual(try store.edits(for: ids[1]).undo.count, 0)
  }

  @MainActor func testLibrarySyncRoutesOpenPhotographThroughEditorAndRevertCoversIt() async throws {
    let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
    let url = try card(in: root)
    let store = try ProjectStore(container: ProjectStore.container(inMemory: true))
    let project = try store.create(title: "Sync")
    let open = PhotoRecord(id: UUID(), fingerprint: try PhotoImportWorker.fingerprint(url), filename: "card.png",
      mediaType: "public.png", width: 64, height: 32, byteCount: 1, bookmark: try PhotoImportWorker.bookmark(url))
    let other = PhotoRecord(id: UUID(), fingerprint: UUID().uuidString, filename: "other.jpg", mediaType: "public.jpeg", width: 64, height: 32, byteCount: 1)
    try store.add(open, to: project.id); try store.add(other, to: project.id)
    let library = LibraryController(store: store, locations: LibraryLocations(root: root))
    library.open(projectID: project.id)
    library.selectAll()
    library.editor.activate(open)
    library.syncEdits([.exposure: .number(0.4)], to: library.actionableIDs)
    await library.batch.waitForCompletion()
    XCTAssertEqual(library.editor.history?.current.exposure, 0.4, "The open photograph is edited in memory")
    XCTAssertEqual(try store.edits(for: open.id).current.exposure, 0.4, "and autosaved")
    XCTAssertEqual(try store.edits(for: other.id).current.exposure, 0.4)
    XCTAssertEqual(library.batch.lastOutcomes.count, 2)
    let report = library.revertLastSync()
    XCTAssertEqual(report.reverted, 2)
    XCTAssertEqual(library.editor.history?.current.exposure, 0)
    XCTAssertEqual(try store.edits(for: other.id).current.exposure, 0)
    await library.editor.waitForPreview()
  }
}
