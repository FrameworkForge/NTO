import Foundation
import Observation

@MainActor @Observable public final class LibraryController {
  public private(set) var photos: [PhotoRecord] = []
  public private(set) var browsing = BrowsingState()
  public private(set) var projectID: UUID?
  public private(set) var isImporting = false
  public private(set) var isCancelling = false
  public private(set) var progress = ""
  public private(set) var completed = 0
  public private(set) var total = 0
  public private(set) var imported = 0
  public private(set) var duplicates = 0
  public private(set) var issues: [String] = []
  public private(set) var hasImportReport = false
  public var errorMessage: String?
  public let previews: PhotoPreviews
  private let store: ProjectStore
  private let worker: PhotoImportWorker
  private var importTask: Task<Void, Never>?
  private var prefetchTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  private var recoveryFinished = false
  public init(store: ProjectStore, locations: LibraryLocations) {
    self.store = store; worker = PhotoImportWorker(locations: locations)
    previews = PhotoPreviews(locations: locations)
  }
  public var activePhoto: PhotoRecord? { photos.first { $0.id == browsing.activeID } }

  public func open(projectID: UUID?) {
    guard self.projectID != projectID else { return }
    flushBrowsing()
    self.projectID = projectID
    do {
      photos = try projectID.map { try store.photos(in: $0) } ?? []
      browsing = try projectID.map { try store.browsingState(for: $0) } ?? BrowsingState()
      let valid = Set(photos.map(\.id))
      browsing.selectedIDs.formIntersection(valid)
      if let active = browsing.activeID, !valid.contains(active) { browsing.activeID = nil }
      if let scroll = browsing.scrollID, !valid.contains(scroll) { browsing.scrollID = nil }
    } catch { photos = []; browsing = BrowsingState(); errorMessage = error.localizedDescription }
  }
  public func select(_ id: UUID, extend: Bool = false, toggle: Bool = false) {
    browsing.select(id, orderedIDs: photos.map(\.id), extend: extend, toggle: toggle)
    scheduleSave()
  }
  public func prefetch(around visibleIDs: [UUID]) {
    prefetchTask?.cancel()
    let visible = Set(visibleIDs)
    let indices = photos.indices.filter { visible.contains(photos[$0].id) }
    guard let first = indices.first, let last = indices.last else { return }
    let neighbours = Array(photos[max(0, first - 8)..<min(photos.count, last + 9)])
    prefetchTask = Task {
      for photo in neighbours {
        if Task.isCancelled { return }
        _ = try? await previews.image(for: photo)
      }
    }
  }
  public func selectAll() {
    browsing.selectedIDs = Set(photos.map(\.id))
    browsing.activeID = browsing.activeID ?? photos.first?.id
    browsing.anchorID = browsing.activeID
    scheduleSave()
  }
  public func setScroll(_ id: UUID?) { browsing.scrollID = id; scheduleSave() }
  public func setDensity(_ density: Double) { browsing.density = min(max(density, 100), 280); scheduleSave() }
  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
      self?.flushBrowsing()
    }
  }
  public func flushBrowsing() {
    saveTask?.cancel(); saveTask = nil
    guard let projectID else { return }
    do { try store.saveBrowsingState(browsing, for: projectID) }
    catch { errorMessage = "Browsing state could not be saved: \(error.localizedDescription)" }
  }
  public func dismissReport() { hasImportReport = false }
  public func cancelImport() { isCancelling = true; importTask?.cancel() }

  /// Import commits one valid asset at a time. Cancellation keeps previously committed assets.
  public func startImport(urls: [URL], projectID: UUID, storage: ImportStorage, caption: String) {
    guard !isImporting else { return }
    isImporting = true; isCancelling = false; hasImportReport = false
    completed = 0; total = 0; imported = 0; duplicates = 0; issues = []; progress = "Finding photographs…"
    let access = urls.filter { $0.startAccessingSecurityScopedResource() }
    importTask = Task {
      defer {
        access.forEach { $0.stopAccessingSecurityScopedResource() }
        isImporting = false; isCancelling = false; hasImportReport = true; importTask = nil
        if self.projectID == projectID {
          do { photos = try store.photos(in: projectID) } catch { errorMessage = error.localizedDescription }
        }
      }
      do {
        if !recoveryFinished {
          try await worker.recoverUncommittedCopies(keeping: store.allManagedPaths())
          recoveryFinished = true
        }
        let discovery = try await worker.discover(urls)
        issues = discovery.issues
        total = discovery.candidates.count
        for candidate in discovery.candidates {
          try Task.checkCancellation()
          progress = candidate.url.lastPathComponent
          var prepared: PhotoRecord?
          do {
            let inspected = try await worker.inspect(candidate, caption: caption)
            if let existing = try store.photo(fingerprint: inspected.fingerprint) {
              if try store.add(existing.record, to: projectID) { imported += 1 }
              else { duplicates += 1 }
            } else {
              let record = try await worker.prepare(inspected, source: candidate.url, storage: storage)
              prepared = record
              // Reject corrupt/system-unsupported images before their database record becomes visible.
              _ = try await previews.image(for: record)
              try Task.checkCancellation()
              _ = try store.add(record, to: projectID)
              prepared = nil
              imported += 1
            }
          } catch {
            if let prepared {
              do { try await worker.discard(prepared) }
              catch { issues.append("Temporary copy cleanup: \(error.localizedDescription)") }
            }
            if error is CancellationError { throw error }
            issues.append(error.localizedDescription)
          }
          completed += 1
          // Avoid refetching the whole library once per image in a large import.
          if completed % 50 == 0, self.projectID == projectID { photos = try store.photos(in: projectID) }
        }
        progress = total == 0 ? "No files found" : "Import complete"
      } catch is CancellationError { progress = "Import cancelled. Completed photographs were kept." }
      catch { progress = "Import stopped"; issues.append(error.localizedDescription) }
    }
  }
  public func waitForImport() async { await importTask?.value }
  public func relink(_ photo: PhotoRecord, to url: URL) async {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try await worker.verifiedBookmark(for: url, matching: photo.fingerprint)
      try store.relink(id: photo.id, bookmark: bookmark)
      if let projectID { photos = try store.photos(in: projectID) }
    } catch { errorMessage = error.localizedDescription }
  }
}
