import Foundation
import SwiftData

public struct EditHistory: Codable, Equatable, Sendable {
  public private(set) var current: EditRecipe
  public private(set) var undo: [EditRecipe] = []
  public private(set) var redo: [EditRecipe] = []
  private var gestureStart: EditRecipe?
  public init(assetID: UUID) { current = .neutral(assetID: assetID) }
  public mutating func beginGesture() { if gestureStart == nil { gestureStart = current } }
  public mutating func set(_ recipe: EditRecipe) throws {
    try recipe.validate()
    guard recipe.assetId == current.assetId else { throw RenderFailure.assetMismatch }
    guard !recipe.hasSameAdjustments(as: current) else { return }
    if gestureStart == nil { undo.append(current); trim(); redo = [] }
    var next = recipe; next.revision = current.revision + 1; current = next
  }
  public mutating func endGesture() {
    if let start = gestureStart, !start.hasSameAdjustments(as: current) {
      undo.append(start); trim(); redo = []
    }
    gestureStart = nil
  }
  public mutating func undoEdit() {
    endGesture()
    guard var previous = undo.popLast() else { return }
    redo.append(current); previous.revision = current.revision + 1; current = previous
  }
  public mutating func redoEdit() {
    endGesture()
    guard var next = redo.popLast() else { return }
    undo.append(current); trim(); next.revision = current.revision + 1; current = next
  }
  public func validate(assetID: UUID) throws {
    for recipe in [current] + undo + redo + (gestureStart.map { [$0] } ?? []) {
      try recipe.validate(); guard recipe.assetId == assetID else { throw RenderFailure.assetMismatch }
    }
    guard undo.count <= 100, redo.count <= 100 else { throw RenderFailure.invalidRecipe }
  }
  private mutating func trim() { if undo.count > 100 { undo.removeFirst(undo.count - 100) } }
}
@Model public final class LocalEditState {
  @Attribute(.unique) public var assetID: UUID
  public var journal: Data
  public init(assetID: UUID, journal: Data) { self.assetID = assetID; self.journal = journal }
}
extension ProjectStore {
  public func edits(for assetID: UUID) throws -> EditHistory {
    let request = FetchDescriptor<LocalEditState>(predicate: #Predicate { $0.assetID == assetID })
    guard let saved = try context.fetch(request).first else { return EditHistory(assetID: assetID) }
    var history = try JSONDecoder().decode(EditHistory.self, from: saved.journal)
    try history.validate(assetID: assetID); history.endGesture()
    return history
  }
  public func saveEdits(_ history: EditHistory) throws {
    let assetID = history.current.assetId
    try history.validate(assetID: assetID)
    let photo = FetchDescriptor<LocalPhoto>(predicate: #Predicate { $0.id == assetID })
    guard try context.fetchCount(photo) == 1 else { throw RenderFailure.assetMismatch }
    let data = try JSONEncoder().encode(history)
    let request = FetchDescriptor<LocalEditState>(predicate: #Predicate { $0.assetID == assetID })
    let saved = try context.fetch(request).first ?? LocalEditState(assetID: assetID, journal: data)
    if saved.modelContext == nil { context.insert(saved) }
    saved.journal = data
    do { try context.save() } catch { context.rollback(); throw error }
  }
}
