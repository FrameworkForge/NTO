import Foundation
import Observation
import ImageIO

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
  private let store: ProjectStore
  private let locations: LibraryLocations
  private let renderer: any PhotoRenderer
  private var task: Task<Void, Never>?
  private var requestID = UUID()
  public init(store: ProjectStore, locations: LibraryLocations, renderer: any PhotoRenderer = CoreImageRenderer()) {
    self.store = store; self.locations = locations; self.renderer = renderer
  }
  public func activate(_ photo: PhotoRecord?) { isActive = true; open(photo); requestPreview() }
  public func deactivate() { finishGesture(); cancelPreview(); isActive = false }
  public func open(_ photo: PhotoRecord?) {
    if self.photo?.id == photo?.id, self.photo?.locationRevision == photo?.locationRevision, history != nil { return }
    finishGesture()
    guard isSaved else { return }
    cancelPreview(); self.photo = photo; history = nil; preview = nil; previewImage = nil; loadError = nil; renderError = nil
    guard let photo else { return }
    do { history = try store.edits(for: photo.id); requestPreview() }
    catch { loadError = "Saved edits could not open: \(error). Your saved data has been kept." }
  }
  public func beginGesture() { history?.beginGesture() }
  public func finishGesture() { history?.endGesture(); save() }
  public func set(_ path: WritableKeyPath<EditRecipe, Double>, value: Double) {
    guard var next = history?.current else { return }
    next[keyPath: path] = value
    do { try history?.set(next); save(); requestPreview() }
    catch { saveError = error.localizedDescription }
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
    guard let photo, let recipe = history?.current else { return }
    let id = UUID(); requestID = id; isRendering = true; renderError = nil
    let renderer = renderer, locations = locations
    task = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(120))
        guard photo.managedPath != nil || photo.bookmark != nil else { throw RenderFailure.missingOriginal }
        let url = try photo.managedPath.map { try locations.managedURL($0) } ?? locations.root
        let reference = OriginalReference(assetID: photo.id, url: url, bookmark: photo.bookmark, fingerprint: photo.fingerprint)
        let rendered = try await renderer.render(original: reference, recipe: recipe,
          output: RenderSpecification(maxDimension: 2000, format: "png"))
        guard !Task.isCancelled, let self, self.requestID == id else { return }
        let decoded = await Task.detached {
          guard let source = CGImageSourceCreateWithData(rendered.data as CFData, nil) else { return nil as CGImage? }
          return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }.value
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
