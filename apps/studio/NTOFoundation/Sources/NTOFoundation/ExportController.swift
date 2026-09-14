import Foundation
import Observation

/// Renders each selected photograph's saved recipe at export size and writes it to the chosen folder, one at a time,
/// off the main actor for rendering and file work. Originals are only ever read.
@MainActor @Observable public final class ExportController {
  public enum Outcome: Equatable, Sendable {
    case exported(URL)
    case skipped(String)
    case failed(String)
  }
  public struct Item: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public var outcome: Outcome?
  }
  public private(set) var isRunning = false
  public private(set) var items: [Item] = []
  public private(set) var completed = 0
  public private(set) var destination: URL?
  public private(set) var summary: String?
  public private(set) var current: String?
  public var hasReport: Bool { summary != nil }
  private let store: ProjectStore
  private let locations: LibraryLocations
  private let renderer: any PhotoRenderer
  private var task: Task<Void, Never>?
  public init(store: ProjectStore, locations: LibraryLocations, renderer: any PhotoRenderer = CoreImageRenderer()) {
    self.store = store; self.locations = locations; self.renderer = renderer
  }
  public var exportedCount: Int { items.filter { if case .exported = $0.outcome { true } else { false } }.count }
  public var failures: [Item] { items.filter { if case .failed = $0.outcome { true } else { false } } }
  public var skipped: [Item] { items.filter { if case .skipped = $0.outcome { true } else { false } } }

  public func start(_ specification: ExportSpecification, photos: [PhotoRecord], projectTitle: String, destination: URL) {
    guard !isRunning, !photos.isEmpty else { return }
    isRunning = true; completed = 0; summary = nil; current = nil; self.destination = destination
    items = photos.map { Item(id: $0.id, filename: $0.filename, outcome: nil) }
    let renderer = renderer, locations = locations
    task = Task { [weak self] in
      let access = destination.startAccessingSecurityScopedResource()
      defer { if access { destination.stopAccessingSecurityScopedResource() } }
      var reachable = FileManager.default.isWritableFile(atPath: destination.path)
      if !reachable, (try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)) != nil {
        reachable = FileManager.default.isWritableFile(atPath: destination.path)
      }
      for (index, photo) in photos.enumerated() {
        guard let self else { return }
        if Task.isCancelled { break }
        self.current = photo.filename
        let outcome: Outcome
        do {
          guard reachable else { throw ExportError.destinationUnavailable }
          let recipe = try self.store.edits(for: photo.id).current
          guard photo.managedPath != nil || photo.bookmark != nil else { throw RenderFailure.missingOriginal }
          let url = try photo.managedPath.map { try locations.managedURL($0) } ?? locations.root
          let reference = OriginalReference(assetID: photo.id, url: url, bookmark: photo.bookmark, fingerprint: photo.fingerprint)
          let name = ExportNaming.filename(template: specification.filenameTemplate, photo: photo, projectTitle: projectTitle,
            index: index + 1, count: photos.count, format: specification.format)
          guard let target = ExportNaming.resolve(destination.appendingPathComponent(name), policy: specification.conflicts) else {
            throw ExportError.exists
          }
          let rendered = try await renderer.render(original: reference, recipe: recipe, output: specification.renderSpecification)
          try Task.checkCancellation()
          let descriptive = ExportWriter.Descriptive(caption: photo.caption, keywords: photo.keywords)
          let policy = specification.metadata, includeLocation = specification.includeLocation
          try await Task.detached {
            try ExportWriter.write(rendered, to: target, policy: policy, includeLocation: includeLocation,
              original: reference, descriptive: descriptive)
          }.value
          outcome = .exported(target)
        } catch ExportError.exists {
          outcome = .skipped(ExportError.exists.localizedDescription)
        } catch is CancellationError {
          break
        } catch {
          outcome = .failed(error.localizedDescription)
        }
        self.items[index].outcome = outcome
        self.completed = index + 1
      }
      guard let self else { return }
      let exported = self.exportedCount, failed = self.failures.count, skipped = self.skipped.count
      var text = Task.isCancelled ? "Export stopped after \(self.completed) of \(photos.count). " : ""
      text += "\(exported) exported"
      if skipped > 0 { text += ", \(skipped) skipped" }
      if failed > 0 { text += ", \(failed) failed" }
      self.summary = text + "."
      self.current = nil; self.isRunning = false; self.task = nil
    }
  }
  public func cancel() { task?.cancel() }
  public func waitForCompletion() async { await task?.value }
  public func dismissReport() { summary = nil; items = [] }
}
