import SwiftData
import XCTest

@testable import NTOFoundation

final class FoundationTests: XCTestCase {
  func testSharedFixtureRoundTrip() throws {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: "ecosystem", withExtension: "json", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: url)
    let fixture = try JSONDecoder().decode(EcosystemFixture.self, from: data)
    XCTAssertEqual(fixture.projects.first?.title, "Studies in light")
    let encoded =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture)) as! [String: Any]
    let assets = encoded["assets"] as! [[String: Any]]
    XCTAssertTrue(assets[0]["originalObjectKey"] is NSNull)
    let recipes = encoded["recipes"] as! [[String: Any]]
    XCTAssertTrue(recipes[0]["temperature"] is NSNull)
    XCTAssertEqual(
      fixture, try JSONDecoder().decode(EcosystemFixture.self, from: JSONEncoder().encode(fixture)))
  }
  func testUnsupportedVersionsAreRejected() throws {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: "ecosystem", withExtension: "json", subdirectory: "Fixtures"))
    let source = try String(contentsOf: url, encoding: .utf8)
    for field in ["schemaVersion", "contractVersion"] {
      let changed = source.replacingOccurrences(of: "\"\(field)\": 1", with: "\"\(field)\": 2")
      XCTAssertThrowsError(
        try JSONDecoder().decode(EcosystemFixture.self, from: Data(changed.utf8)))
    }
  }
  @MainActor func testFocusRestoresChromeAndSelectionSurvivesModes() async {
    let state = WorkspaceState()
    let id = UUID()
    state.selectedAssetID = id
    state.inspectorVisible = false
    state.toggleFocus()
    XCTAssertFalse(state.sidebarVisible)
    XCTAssertFalse(state.inspectorVisible)
    for mode in StudioMode.allCases {
      state.mode = mode
      XCTAssertEqual(state.selectedAssetID, id)
    }
    state.toggleFocus()
    XCTAssertTrue(state.sidebarVisible)
    XCTAssertFalse(state.inspectorVisible)
  }
  @MainActor func testProjectsPersistAcrossReopenAndRejectEmptyRename() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("test.store")
    let id: UUID = try {
      let store = try ProjectStore(container: ProjectStore.container(url: url))
      let p = try store.create(title: "First shoot")
      try store.rename(p, title: "Renamed shoot")
      XCTAssertThrowsError(try store.rename(p, title: "  "))
      return p.id
    }()
    let reopened = try ProjectStore(container: ProjectStore.container(url: url))
    XCTAssertEqual(reopened.projects.first?.id, id)
    XCTAssertEqual(reopened.projects.first?.title, "Renamed shoot")
  }
}
