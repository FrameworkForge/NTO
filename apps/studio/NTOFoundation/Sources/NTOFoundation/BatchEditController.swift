import Foundation
import Observation

/// Applies a parameter subset to many photographs' saved edit journals without blocking the interface.
/// Each photograph receives one undo step; `revertLast` undoes that step only where nothing changed afterwards.
@MainActor @Observable public final class BatchEditController {
  public struct Outcome: Sendable, Equatable {
    public let assetID: UUID
    public let revision: Int
    public init(assetID: UUID, revision: Int) { self.assetID = assetID; self.revision = revision }
  }
  public struct RevertReport: Sendable, Equatable {
    public var reverted = 0
    public var skipped = 0
    public var failures: [String] = []
  }
  public private(set) var isRunning = false
  public private(set) var completed = 0
  public private(set) var total = 0
  public private(set) var failures: [String] = []
  public private(set) var summary: String?
  public private(set) var lastOutcomes: [Outcome] = []
  private let store: ProjectStore
  private var task: Task<Void, Never>?
  public init(store: ProjectStore) { self.store = store }

  /// `precommitted` records changes the caller already applied elsewhere (the open editor) so revert covers them too.
  public func sync(_ adjustments: RecipeAdjustments, to targets: [(id: UUID, name: String)], precommitted: [Outcome] = []) {
    guard !isRunning, !adjustments.isEmpty else { return }
    isRunning = true; completed = 0; total = targets.count; failures = []; summary = nil; lastOutcomes = precommitted
    task = Task { [weak self] in
      var outcomes = precommitted
      for (index, target) in targets.enumerated() {
        guard let self else { return }
        if Task.isCancelled { break }
        do {
          var history = try self.store.edits(for: target.id)
          var next = history.current
          try next.apply(adjustments)
          if !next.hasSameAdjustments(as: history.current) {
            try history.set(next)
            try self.store.saveEdits(history)
            outcomes.append(Outcome(assetID: target.id, revision: history.current.revision))
          }
        } catch { self.failures.append("\(target.name): \(error.localizedDescription)") }
        self.completed = index + 1
        if index % 10 == 9 { await Task.yield() }
      }
      guard let self else { return }
      self.lastOutcomes = outcomes
      let applied = outcomes.count
      self.summary = Task.isCancelled
        ? "Sync stopped after \(self.completed) of \(self.total). Completed photographs keep their new edits."
        : "Applied to \(applied) photograph\(applied == 1 ? "" : "s")" + (self.failures.isEmpty ? "." : "; \(self.failures.count) could not be updated.")
      self.isRunning = false; self.task = nil
    }
  }
  public func cancel() { task?.cancel() }
  public func waitForCompletion() async { await task?.value }

  /// Undoes the last sync on every photograph still at the revision the sync produced. Later edits are left alone.
  @discardableResult public func revertLast(excluding handled: Set<UUID> = []) -> RevertReport {
    var report = RevertReport()
    for outcome in lastOutcomes where !handled.contains(outcome.assetID) {
      do {
        var history = try store.edits(for: outcome.assetID)
        guard history.current.revision == outcome.revision, !history.undo.isEmpty else { report.skipped += 1; continue }
        history.undoEdit()
        try store.saveEdits(history)
        report.reverted += 1
      } catch { report.failures.append(error.localizedDescription) }
    }
    lastOutcomes = []
    summary = "Reverted \(report.reverted) photograph\(report.reverted == 1 ? "" : "s")"
      + (report.skipped > 0 ? "; \(report.skipped) edited since and left as they are." : ".")
    return report
  }
}
