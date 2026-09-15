import Foundation
import Observation
import ImageIO
import UniformTypeIdentifiers

@MainActor @Observable public final class EditController {
  public private(set) var isActive = false
  public private(set) var photo: PhotoRecord?
  public private(set) var history: EditHistory?
  public private(set) var preview: RenderedResult?
  public private(set) var previewImage: CGImage?
  public private(set) var isRendering = false
  public private(set) var isSaved = true
  public private(set) var loadError: String?
  public private(set) var saveError: String?
  public private(set) var renderError: String?
  /// True while the original preview is shown in place of the edited render. Never touches the recipe.
  public var isComparing = false
  /// A render of the current recipe with a preset applied, shown while hovering. Never touches the recipe.
  public private(set) var adjustmentPreviewImage: CGImage?
  public private(set) var isPreviewingAdjustments = false
  /// Parameters copied from a photograph, ready to paste or sync. In-memory for this session.
  public private(set) var copied: RecipeAdjustments?
  /// Interactive crop in progress. While set, the preview renders uncropped and unrotated.
  public private(set) var cropSession: CropSession?
  /// 100% inspection of the edited result.
  public private(set) var isInspecting = false
  public private(set) var fullImage: CGImage?
  public private(set) var isRenderingFull = false
  /// White-balance eyedropper armed: the next click on the photograph samples a neutral.
  public var isSamplingWhiteBalance = false
  /// True while the rotation slider is being dragged; the canvas shows a level grid.
  public var isStraightening = false
  public private(set) var sampleError: String?
  private var adjustmentPreviewTask: Task<Void, Never>?
  private var fullTask: Task<Void, Never>?
  private var fullRequestID = UUID()
  private let store: ProjectStore
  private let locations: LibraryLocations
  private let previews: PhotoPreviews?
  private let renderer: any PhotoRenderer
  private var task: Task<Void, Never>?
  private var requestID = UUID()
  public init(store: ProjectStore, locations: LibraryLocations, previews: PhotoPreviews? = nil, renderer: any PhotoRenderer = CoreImageRenderer()) {
    self.store = store; self.locations = locations; self.previews = previews; self.renderer = renderer
  }
  public func activate(_ photo: PhotoRecord?) { isActive = true; open(photo); requestPreview() }
  public func deactivate() {
    finishGesture(); cancelPreview(); clearAdjustmentPreview(); setInspecting(false)
    cropSession = nil; isSamplingWhiteBalance = false; isStraightening = false; isComparing = false; isActive = false
  }
  public func open(_ photo: PhotoRecord?) {
    if self.photo?.id == photo?.id, self.photo?.locationRevision == photo?.locationRevision, history != nil { return }
    finishGesture()
    guard isSaved else { return }
    cancelPreview(); clearAdjustmentPreview(); setInspecting(false)
    cropSession = nil; isSamplingWhiteBalance = false; sampleError = nil
    self.photo = photo; history = nil; preview = nil; previewImage = nil; loadError = nil; renderError = nil
    isComparing = false
    guard let photo else { return }
    do { history = try store.edits(for: photo.id); requestPreview() }
    catch { loadError = "Saved edits could not open: \(error). Your saved data has been kept." }
  }
  public func beginGesture() { history?.beginGesture() }
  public func finishGesture() { history?.endGesture(); save() }

  /// Every recipe change flows through here: validate, record history, autosave, re-render.
  public func apply(_ change: (inout EditRecipe) -> Void) {
    guard var next = history?.current else { return }
    change(&next)
    do { try history?.set(next); save(); requestPreview() }
    catch { saveError = error.localizedDescription }
  }
  public func set(_ path: WritableKeyPath<EditRecipe, Double>, value: Double) {
    apply { $0[keyPath: path] = value }
  }
  /// `nil` keeps the camera's as-shot white balance for RAW and the existing appearance for raster images.
  public func setTemperature(_ kelvin: Double?) {
    apply { $0.temperature = kelvin.map { min(max($0, 2000), 50000) } }
  }
  public func setCrop(_ crop: EditRecipeCrop) {
    apply { $0.crop = EditRecipe.clampedCrop(crop) }
  }
  public func setRotation(_ degrees: Double) {
    apply { $0.rotation = EditRecipe.normalizedRotation(degrees) }
  }
  public func rotate(by degrees: Double) {
    apply { $0.rotation = EditRecipe.normalizedRotation($0.rotation + degrees) }
  }
  public func reset(_ group: EditGroup) {
    apply { $0.reset(group) }
  }
  /// Applies a preset or pasted subset as one undo step; parameters outside the subset keep their values.
  public func apply(_ adjustments: RecipeAdjustments) {
    guard var next = history?.current else { return }
    do { try next.apply(adjustments); try history?.set(next); save(); requestPreview() }
    catch { saveError = error.localizedDescription }
  }
  public func copy(_ parameters: Set<EditParameter>) {
    guard let current = history?.current, !parameters.isEmpty else { return }
    copied = current.adjustments(for: parameters)
  }
  public func paste() { if let copied { apply(copied) } }

  /// The recipe the preview shows: the current one, or uncropped and unrotated while a crop session is open.
  public var previewRecipe: EditRecipe? {
    guard var recipe = history?.current else { return nil }
    if cropSession != nil { recipe.crop = EditRecipeCrop(x: 0, y: 0, width: 1, height: 1); recipe.rotation = 0 }
    return recipe
  }
  public func beginCrop() {
    guard let current = history?.current, cropSession == nil else { return }
    setInspecting(false); isSamplingWhiteBalance = false
    cropSession = CropSession(initial: current.crop)
    requestPreview()
  }
  public func updateCrop(_ crop: EditRecipeCrop) {
    guard cropSession != nil else { return }
    cropSession?.pending = EditRecipe.clampedCrop(crop, minimumSize: CropGeometry.minimumSize)
  }
  public func setCropAspect(_ aspect: CropAspect, portrait: Bool) {
    guard var session = cropSession, let photo else { return }
    session.aspect = aspect; session.portrait = portrait
    let size = CGSize(width: photo.width, height: photo.height)
    session.pending = CropGeometry.fitted(aspect: CropGeometry.heightFactor(aspect: aspect, portrait: portrait, imageSize: size), within: session.pending)
    cropSession = session
  }
  /// Return: the pending rectangle becomes one undo step. No change means no history entry.
  public func commitCrop() {
    guard let session = cropSession else { return }
    cropSession = nil
    if session.pending != session.initial { setCrop(session.pending) } else { requestPreview() }
  }
  /// Escape: the crop that was in force when the session began stays untouched.
  public func cancelCrop() {
    guard cropSession != nil else { return }
    cropSession = nil
    requestPreview()
  }

  public func setInspecting(_ inspecting: Bool) {
    guard inspecting != isInspecting else { return }
    isInspecting = inspecting
    if inspecting { cropSession = nil; requestFullResolution() }
    else { fullTask?.cancel(); fullTask = nil; fullRequestID = UUID(); fullImage = nil; isRenderingFull = false }
  }
  public func requestFullResolution() {
    fullTask?.cancel()
    guard isInspecting, let photo, let recipe = history?.current else { return }
    let id = UUID(); fullRequestID = id; isRenderingFull = true
    let renderer = renderer, locations = locations
    fullTask = Task { [weak self] in
      do {
        let reference = try Self.reference(for: photo, locations: locations)
        let rendered = try await renderer.render(original: reference, recipe: recipe, output: RenderSpecification(maxDimension: 30_000, format: "png"))
        guard !Task.isCancelled, let self, self.fullRequestID == id else { return }
        let decoded = await Self.decode(rendered)
        guard !Task.isCancelled, self.fullRequestID == id else { return }
        self.fullImage = decoded; self.isRenderingFull = false
      } catch {
        guard !Task.isCancelled, let self, self.fullRequestID == id else { return }
        self.renderError = error.localizedDescription; self.isRenderingFull = false
      }
    }
  }
  public func waitForFullResolution() async { await fullTask?.value }

  /// Samples a neutral at a point on the displayed render and sets temperature and tint as one undo step.
  public func sampleWhiteBalance(at displayed: CGPoint) async {
    guard let photo, let recipe = history?.current else { return }
    sampleError = nil
    let point = CropGeometry.originalPoint(fromDisplayed: displayed, crop: cropSession == nil ? recipe.crop : EditRecipeCrop(x: 0, y: 0, width: 1, height: 1),
      rotation: cropSession == nil ? recipe.rotation : 0, imageSize: CGSize(width: photo.width, height: photo.height))
    do {
      let solution: (temperature: Double, tint: Double)
      if UTType(photo.mediaType)?.conforms(to: .rawImage) == true {
        let reference = try Self.reference(for: photo, locations: locations)
        solution = try await Task.detached { try WhiteBalanceSampler.rawNeutral(original: reference, at: point) }.value
      } else {
        guard let previews else { throw RenderFailure.missingOriginal }
        let image = try await previews.image(for: photo, maxPixel: 2000)
        let colour = try WhiteBalanceSampler.averageLinearColour(in: image, at: point)
        solution = await Task.detached { WhiteBalanceSampler.neutral(forLinear: colour) }.value
      }
      apply { $0.temperature = solution.temperature; $0.tint = solution.tint }
    } catch { sampleError = error.localizedDescription }
    isSamplingWhiteBalance = false
  }

  /// Renders the current recipe with `adjustments` for a hover preview. Best effort: failures keep the edited preview.
  public func previewAdjustments(_ adjustments: RecipeAdjustments) {
    adjustmentPreviewTask?.cancel()
    guard let photo, var recipe = history?.current else { return }
    do { try recipe.apply(adjustments) } catch { return }
    isPreviewingAdjustments = true
    let renderer = renderer, locations = locations, candidate = recipe
    adjustmentPreviewTask = Task { [weak self] in
      guard let reference = try? Self.reference(for: photo, locations: locations) else { return }
      guard let rendered = try? await renderer.render(original: reference, recipe: candidate,
        output: RenderSpecification(maxDimension: 2000, format: "png")) else { return }
      guard !Task.isCancelled, let self, self.isPreviewingAdjustments else { return }
      let decoded = await Self.decode(rendered)
      guard !Task.isCancelled, self.isPreviewingAdjustments else { return }
      self.adjustmentPreviewImage = decoded
    }
  }
  public func clearAdjustmentPreview() {
    adjustmentPreviewTask?.cancel(); adjustmentPreviewTask = nil
    isPreviewingAdjustments = false; adjustmentPreviewImage = nil
  }
  private static func reference(for photo: PhotoRecord, locations: LibraryLocations) throws -> OriginalReference {
    guard photo.managedPath != nil || photo.bookmark != nil else { throw RenderFailure.missingOriginal }
    let url = try photo.managedPath.map { try locations.managedURL($0) } ?? locations.root
    return OriginalReference(assetID: photo.id, url: url, bookmark: photo.bookmark, fingerprint: photo.fingerprint)
  }
  private static func decode(_ rendered: RenderedResult) async -> CGImage? {
    await Task.detached {
      guard let source = CGImageSourceCreateWithData(rendered.data as CFData, nil) else { return nil as CGImage? }
      return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }.value
  }
  public func reset() {
    guard let photo else { return }
    do { try history?.set(.neutral(assetID: photo.id)); save(); requestPreview() }
    catch { saveError = error.localizedDescription }
  }
  public func undo() { history?.undoEdit(); save(); requestPreview() }
  public func redo() { history?.redoEdit(); save(); requestPreview() }
  public func save() {
    guard let history else { return }
    do { try store.saveEdits(history); isSaved = true; saveError = nil }
    catch { isSaved = false; saveError = "Edits are not saved: \(error.localizedDescription). Retry before changing photographs." }
  }
  public func retry() {
    if history == nil { let selected = photo; photo = nil; open(selected) }
    else { save(); requestPreview() }
  }
  public func cancelPreview() {
    task?.cancel(); task = nil; requestID = UUID(); isRendering = false
  }
  public func requestPreview() {
    task?.cancel()
    if isInspecting { requestFullResolution() }
    guard let photo, let recipe = previewRecipe else { return }
    let id = UUID(); requestID = id; isRendering = true; renderError = nil
    let renderer = renderer, locations = locations
    task = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(120))
        let reference = try Self.reference(for: photo, locations: locations)
        let rendered = try await renderer.render(original: reference, recipe: recipe,
          output: RenderSpecification(maxDimension: 2000, format: "png"))
        guard !Task.isCancelled, let self, self.requestID == id else { return }
        let decoded = await Self.decode(rendered)
        guard !Task.isCancelled, self.requestID == id else { return }
        self.preview = rendered; self.previewImage = decoded; self.isRendering = false
        if decoded == nil { self.renderError = RenderFailure.decode.localizedDescription }
      } catch {
        guard !Task.isCancelled, let self, self.requestID == id else { return }
        self.renderError = error.localizedDescription; self.isRendering = false
      }
    }
  }
  public func waitForPreview() async { await task?.value }
}
