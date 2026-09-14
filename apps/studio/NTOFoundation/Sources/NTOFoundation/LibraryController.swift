import Foundation
import Observation

@MainActor @Observable public final class LibraryController {
  public private(set) var photos: [PhotoRecord] = [] { didSet { rebuildVisiblePhotos() } }
  public private(set) var collections: [CollectionRecord] = [] { didSet { rebuildVisiblePhotos() } }
  public private(set) var query = LibraryQuery() { didSet { rebuildVisiblePhotos() } }
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
  public let editor: EditController
  public let previews: PhotoPreviews
  public let presets: PresetStore
  public let batch: BatchEditController
  public let exporter: ExportController
  private let store: ProjectStore
  private let worker: PhotoImportWorker
  private var importTask: Task<Void, Never>?
  private var prefetchTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  private var recoveryFinished = false
  public init(store: ProjectStore, locations: LibraryLocations) {
    previews = PhotoPreviews(locations: locations)
    editor = EditController(store: store, locations: locations, previews: previews)
    self.store = store; worker = PhotoImportWorker(locations: locations)
    presets = PresetStore(directory: locations.presets)
    batch = BatchEditController(store: store)
    exporter = ExportController(store: store, locations: locations)
  }

  /// Exports the selected, visible photographs in their displayed order using their saved recipes.
  public func export(_ specification: ExportSpecification, to destination: URL, projectTitle: String) {
    editor.finishGesture()
    let selected = visiblePhotos.filter { actionableIDs.contains($0.id) }
    exporter.start(specification, photos: selected, projectTitle: projectTitle, destination: destination)
  }

  /// Applies a parameter subset to the given photographs. The photograph open in Edit goes through the editor so its
  /// in-memory history stays authoritative; every other photograph is updated in the background.
  public func syncEdits(_ adjustments: RecipeAdjustments, to ids: Set<UUID>) {
    guard !batch.isRunning, !adjustments.isEmpty else { return }
    var targets = ids
    var precommitted: [BatchEditController.Outcome] = []
    if editor.isActive, let active = editor.photo?.id, targets.contains(active) {
      let before = editor.history?.current.revision
      editor.apply(adjustments)
      if let after = editor.history?.current.revision, after != before {
        precommitted.append(BatchEditController.Outcome(assetID: active, revision: after))
      }
      targets.remove(active)
    }
    let named = photos.filter { targets.contains($0.id) }.map { (id: $0.id, name: $0.filename) }
    batch.sync(adjustments, to: named, precommitted: precommitted)
  }
  /// Reverts the last sync. The open photograph is undone through the editor when it is still at the synced revision.
  @discardableResult public func revertLastSync() -> BatchEditController.RevertReport {
    var handled: Set<UUID> = []
    var report = BatchEditController.RevertReport()
    if editor.isActive, let active = editor.photo?.id, let outcome = batch.lastOutcomes.first(where: { $0.assetID == active }) {
      handled.insert(active)
      if editor.history?.current.revision == outcome.revision { editor.undo(); report.reverted += 1 } else { report.skipped += 1 }
    }
    let rest = batch.revertLast(excluding: handled)
    report.reverted += rest.reverted; report.skipped += rest.skipped; report.failures += rest.failures
    return report
  }
  public var activePhoto: PhotoRecord? { photos.first { $0.id == browsing.activeID } }

  public private(set) var visiblePhotos: [PhotoRecord] = []
  private func rebuildVisiblePhotos() {
    visiblePhotos = query.apply(to: photos, members: query.collectionID.map { id in collections.first { $0.id == id }?.photoIDs ?? [] })
  }
  public var actionableIDs: Set<UUID> { browsing.selectedIDs.intersection(visiblePhotos.map(\.id)) }
  public func setQuery(_ value: LibraryQuery) { query = value; scheduleSave() }
  public func navigate(_ delta: Int) {
    let ids = visiblePhotos.map(\.id)
    guard !ids.isEmpty else { return }
    let current = browsing.activeID.flatMap { ids.firstIndex(of: $0) } ?? (delta > 0 ? -1 : ids.count)
    select(ids[min(max(current + delta, 0), ids.count - 1)])
    prefetch(around: browsing.activeID.map { [$0] } ?? [])
  }
  public func annotate(rating: Int? = nil, flag: PhotoFlag? = nil, favourite: Bool? = nil,
    caption: String? = nil, keywords: [String]? = nil, activeOnly: Bool = false) {
    let oldIndex = visiblePhotos.firstIndex { $0.id == browsing.activeID } ?? 0
    let ids = activeOnly ? Set(browsing.activeID.map { [$0] } ?? []).intersection(actionableIDs) : actionableIDs
    do {
      try store.annotate(ids, rating: rating, flag: flag, favourite: favourite, caption: caption, keywords: keywords)
      photos = photos.map { record in
        guard ids.contains(record.id) else { return record }
        var edited = record
        if let rating { edited.rating = rating }
        if let flag { edited.flag = flag }
        if let favourite { edited.isFavourite = favourite }
        if let caption { edited.caption = caption }
        if let keywords { edited.keywords = Array(Set(keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted() }
        return edited
      }
    } catch { errorMessage = error.localizedDescription; return }
    if activeOnly, !visiblePhotos.isEmpty, !visiblePhotos.contains(where: { $0.id == browsing.activeID }) {
      select(visiblePhotos[min(oldIndex, visiblePhotos.count - 1)].id)
    }
  }
  public func createCollection(title: String) {
    guard let projectID else { return }
    performOrganisation { _ = try store.createCollection(title: title, projectID: projectID) }
  }
  public func renameCollection(_ id: UUID, title: String) { performOrganisation { try store.renameCollection(id, title: title) } }
  public func removeCollection(_ id: UUID) {
    performOrganisation { try store.removeCollection(id) }
    if !collections.contains(where: { $0.id == id }), query.collectionID == id { query.collectionID = nil; scheduleSave() }
  }
  public func moveCollection(_ id: UUID, offset: Int) { performOrganisation { try store.moveCollection(id, offset: offset) } }
  public func collect(in id: UUID, included: Bool) {
    performOrganisation { try store.setCollectionMembership(actionableIDs, collectionID: id, included: included) }
  }
  private func performOrganisation(_ operation: () throws -> Void) {
    do {
      try operation()
      if let projectID { collections = try store.collections(in: projectID) }
    } catch { errorMessage = error.localizedDescription }
  }

  public func open(projectID: UUID?) {
    guard self.projectID != projectID else { return }
    flushBrowsing()
    self.projectID = projectID
    do {
      photos = try projectID.map { try store.photos(in: $0) } ?? []
      collections = try projectID.map { try store.collections(in: $0) } ?? []
      query = try projectID.map { try store.libraryQuery(for: $0) } ?? LibraryQuery()
      if let id = query.collectionID, !collections.contains(where: { $0.id == id }) { query.collectionID = nil }
      browsing = try projectID.map { try store.browsingState(for: $0) } ?? BrowsingState()
      let valid = Set(photos.map(\.id))
      browsing.selectedIDs.formIntersection(valid)
      if let active = browsing.activeID, !valid.contains(active) { browsing.activeID = nil }
      if let scroll = browsing.scrollID, !valid.contains(scroll) { browsing.scrollID = nil }
    } catch { photos = []; collections = []; query = LibraryQuery(); browsing = BrowsingState(); errorMessage = error.localizedDescription }
  }
  public func select(_ id: UUID, extend: Bool = false, toggle: Bool = false) {
    browsing.select(id, orderedIDs: visiblePhotos.map(\.id), extend: extend, toggle: toggle)
    scheduleSave()
  }
  public func prefetch(around visibleIDs: [UUID], maxPixel: Int = 512) {
    prefetchTask?.cancel()
    let visible = Set(visibleIDs)
    let candidates = visiblePhotos
    let indices = candidates.indices.filter { visible.contains(candidates[$0].id) }
    guard let first = indices.first, let last = indices.last else { return }
    let nearby = max(0, first - 4)..<min(candidates.count, last + 5)
    let neighbours = nearby.sorted { a, b in
      let da = max(first - a, a - last, 0), db = max(first - b, b - last, 0)
      return da == db ? a < b : da < db
    }.map { candidates[$0] }
    prefetchTask = Task {
      for photo in neighbours {
        if Task.isCancelled { return }
        _ = try? await previews.image(for: photo, maxPixel: maxPixel)
      }
    }
  }
  public func selectAll() {
    browsing.selectedIDs = Set(visiblePhotos.map(\.id))
    browsing.activeID = visiblePhotos.first(where: { $0.id == browsing.activeID })?.id ?? visiblePhotos.first?.id
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
    do { try store.saveBrowsingState(browsing, for: projectID); try store.saveLibraryQuery(query, for: projectID) }
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
