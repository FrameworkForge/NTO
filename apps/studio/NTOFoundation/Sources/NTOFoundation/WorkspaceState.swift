import Foundation
import Observation

public enum StudioMode: String, CaseIterable, Identifiable, Sendable {
  case library = "Library"
  case cull = "Cull"
  case edit = "Edit"
  case publish = "Publish"
  public var id: String { rawValue }
  public var symbol: String {
    switch self {
    case .library: "square.grid.2x2"
    case .cull: "rectangle.on.rectangle"
    case .edit: "slider.horizontal.3"
    case .publish: "arrow.up.right.square"
    }
  }
}
@MainActor @Observable public final class WorkspaceState {
  public var mode: StudioMode = .library
  public var newProjectRequested = false
  public var importRequested = false
  public var exportRequested = false
  public var selectedProjectID: UUID?
  public var selectedAssetID: UUID?
  public var sidebarVisible = true
  public var inspectorVisible = true
  public private(set) var isFocused = false
  private var previousChrome = (true, true)
  public init() {}
  public func toggleFocus() {
    if isFocused {
      (sidebarVisible, inspectorVisible) = previousChrome
    } else {
      previousChrome = (sidebarVisible, inspectorVisible)
      sidebarVisible = false
      inspectorVisible = false
    }
    isFocused.toggle()
  }
}
