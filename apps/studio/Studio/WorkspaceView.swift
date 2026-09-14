import AppKit
import UniformTypeIdentifiers
import NTOFoundation
import SwiftUI

/// The native workspace: a sidebar of projects and collections, a segmented mode picker in the toolbar,
/// the content for the current mode, and an inspector that shows Info or Adjustments. Composition only;
/// state and work live in `WorkspaceState`, `ProjectStore` and `LibraryController`.
struct WorkspaceView: View {
  @Bindable var workspace: WorkspaceState
  @Bindable var store: ProjectStore
  @Bindable var library: LibraryController
  @State private var showImportSheet = false
  @State private var showExportSheet = false
  @State private var importURLs: [URL] = []
  @State private var dropTargeted = false
  @AppStorage("lastProjectID") private var lastProjectID = ""
  @Environment(\.scenePhase) private var scenePhase
  @State private var showProjectSheet = false
  @State private var editingProject: LocalProject?
  @State private var projectTitle = ""
  @State private var showCollectionSheet = false
  @State private var editingCollectionID: UUID?
  @State private var collectionTitle = ""
  @State private var coverRevision = 0
  @State private var errorMessage: String?
  @State private var demo = ProcessInfo.processInfo.arguments.contains("--fixtures")
  private let fixtureID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
  private var selectedProject: LocalProject? { store.projects.first { $0.id == workspace.selectedProjectID } }
  private var columnVisibility: Binding<NavigationSplitViewVisibility> {
    Binding(get: { workspace.sidebarVisible ? .all : .detailOnly },
      set: { if !workspace.isFocused { workspace.sidebarVisible = $0 != .detailOnly } })
  }

  var body: some View {
    NavigationSplitView(columnVisibility: columnVisibility) {
      sidebar.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    } detail: {
      detail
        .navigationTitle(selectedProject?.title ?? "NTO Studio")
        .navigationSubtitle(subtitle)
        .inspector(isPresented: Binding(get: { workspace.inspectorVisible }, set: { if !workspace.isFocused { workspace.inspectorVisible = $0 } })) {
          inspector.inspectorColumnWidth(min: 260, ideal: 290, max: 360)
        }
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        Picker("Mode", selection: $workspace.mode) {
          ForEach(StudioMode.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).frame(width: 320).help("Cmd-1 to Cmd-4")
      }
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Import…") { presentImport() }.disabled(library.isImporting)
        Button("Export…") { presentExport() }.disabled(library.actionableIDs.isEmpty || library.exporter.isRunning)
          .help("Export the selected photographs with their edits (Shift-Cmd-E)")
        Button { if !workspace.isFocused { workspace.inspectorVisible.toggle() } } label: { Image(systemName: "sidebar.trailing") }
          .help("Toggle Inspector").accessibilityLabel("Toggle Inspector").disabled(workspace.isFocused)
        Button { workspace.toggleFocus() } label: {
          Image(systemName: workspace.isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }.help("Focus Mode (Tab)").accessibilityLabel(workspace.isFocused ? "Leave Focus Mode" : "Focus Mode")
      }
    }
    .frame(minWidth: 700, minHeight: 500)
    .preferredColorScheme(.dark).tint(NTOTokens.Color.paper)
    .background(WorkspaceKeyboardShortcuts { workspace.toggleFocus() }.frame(width: 0, height: 0))
    .sheet(isPresented: $showImportSheet) {
      ImportPhotosSheet(library: library, store: store, initialURLs: importURLs) { id in
        demo = false; workspace.selectedProjectID = id; workspace.mode = .library
      }
    }
    .sheet(isPresented: $showExportSheet) { ExportSheet(library: library, projectTitle: selectedProject?.title ?? "") }
    .sheet(isPresented: $showProjectSheet) { projectSheet }
    .sheet(isPresented: $showCollectionSheet) { collectionSheet }
    .alert("Studio needs your attention",
      isPresented: Binding(get: { errorMessage != nil || library.errorMessage != nil }, set: { if !$0 { errorMessage = nil; library.errorMessage = nil } })) {
      Button("OK") { errorMessage = nil; library.errorMessage = nil }
    } message: { Text(errorMessage ?? library.errorMessage ?? "Try again.") }
    .onChange(of: workspace.newProjectRequested) { _, _ in editingProject = nil; projectTitle = ""; showProjectSheet = true }
    .onChange(of: workspace.importRequested) { _, _ in presentImport() }
    .onChange(of: workspace.exportRequested) { _, _ in presentExport() }
    .onChange(of: workspace.selectedProjectID) { _, id in
      library.open(projectID: id)
      workspace.selectedAssetID = library.browsing.activeID
      lastProjectID = id?.uuidString ?? ""
    }
    .onChange(of: library.browsing.activeID) { _, id in workspace.selectedAssetID = id }
    .onChange(of: scenePhase) { _, phase in if phase != .active { library.flushBrowsing(); library.editor.finishGesture() } }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
      library.flushBrowsing(); library.editor.finishGesture()
    }
    .onAppear {
      if workspace.selectedProjectID == nil {
        workspace.selectedProjectID = store.projects.first { $0.id.uuidString == lastProjectID }?.id ?? store.projects.first?.id
      }
      library.open(projectID: workspace.selectedProjectID)
      workspace.selectedAssetID = library.browsing.activeID
    }
  }

  private var subtitle: String {
    if demo { return "Development fixture" }
    let count = library.photos.count
    return "\(count) Photograph\(count == 1 ? "" : "s")"
  }

  // MARK: Sidebar

  private var sidebar: some View {
    List(selection: $workspace.selectedProjectID) {
      Section("Projects") {
        ForEach(store.projects, id: \.id) { project in
          ProjectSummaryLabel(project: project, store: store, library: library, revision: coverRevision)
            .tag(Optional(project.id))
            .contextMenu {
              Button("Rename Project…") { editingProject = project; projectTitle = project.title; showProjectSheet = true }
              Button("Use Selected Photograph as Cover") {
                if let photo = library.activePhoto {
                  do { try store.setProjectCover(photo.id, projectID: project.id); coverRevision += 1 }
                  catch { errorMessage = error.localizedDescription }
                }
              }.disabled(library.projectID != project.id || library.activePhoto == nil)
            }
        }
      }
      Section("Collections") {
        ForEach(library.collections) { collection in
          Button {
            var query = library.query
            query.collectionID = query.collectionID == collection.id ? nil : collection.id
            library.setQuery(query)
            if workspace.mode == .publish { workspace.mode = .library }
          } label: {
            Label(collection.title, systemImage: "rectangle.on.rectangle").badge(collection.photoIDs.count)
              .frame(maxWidth: .infinity, alignment: .leading)
          }.buttonStyle(.plain)
            .listRowBackground(library.query.collectionID == collection.id ? Color.white.opacity(0.12) : Color.clear)
            .accessibilityValue(library.query.collectionID == collection.id ? "Showing" : "")
            .contextMenu {
              Button("Add Selected") { library.collect(in: collection.id, included: true) }.disabled(library.actionableIDs.isEmpty)
              Button("Remove Selected") { library.collect(in: collection.id, included: false) }.disabled(library.actionableIDs.isEmpty)
              Divider()
              Button("Rename…") { editingCollectionID = collection.id; collectionTitle = collection.title; showCollectionSheet = true }
              Button("Move Up") { library.moveCollection(collection.id, offset: -1) }
              Button("Move Down") { library.moveCollection(collection.id, offset: 1) }
              Button("Remove Collection (Keep Photographs)", role: .destructive) { library.removeCollection(collection.id) }
            }
        }
        Button { editingCollectionID = nil; collectionTitle = ""; showCollectionSheet = true } label: {
          Label("New Collection", systemImage: "plus").foregroundStyle(.secondary)
        }.buttonStyle(.plain).disabled(library.projectID == nil)
      }
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading, spacing: 8) {
        Button { editingProject = nil; projectTitle = ""; showProjectSheet = true } label: {
          Label("New Project", systemImage: "plus")
        }.buttonStyle(.plain).foregroundStyle(.secondary).help("New Project (Cmd-N)")
        Toggle("Development fixtures", isOn: $demo).toggleStyle(.checkbox).font(.caption).foregroundStyle(.secondary)
          .onChange(of: demo) { _, enabled in if !enabled { workspace.selectedAssetID = library.browsing.activeID } }
      }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
    }
  }

  // MARK: Content

  private var detail: some View {
    VStack(spacing: 0) {
      if !workspace.isFocused || library.isImporting { LibraryImportStatus(library: library) }
      if !workspace.isFocused || library.exporter.isRunning { ExportStatus(library: library) }
      ZStack {
        NTOTokens.Color.black
        if demo {
          fixtureCanvas
        } else if library.photos.isEmpty && workspace.mode != .publish {
          ContentUnavailableView {
            Label(emptyTitle, systemImage: workspace.mode.symbol)
          } description: { Text(emptyDescription) } actions: {
            if workspace.mode == .library { Button("Import Photographs…") { presentImport() }.disabled(library.isImporting) }
          }
        } else {
          switch workspace.mode {
          case .library:
            PhotoLibraryGrid(library: library, isFocused: workspace.isFocused) { workspace.mode = .cull }.id(library.projectID)
          case .cull, .edit:
            SelectedPhotoCanvas(library: library, mode: workspace.mode, isFocused: workspace.isFocused)
          case .publish:
            PublishWorkspace(library: library, projectTitle: selectedProject?.title ?? "", projectCoverID: currentCoverID) { id in
              guard let project = selectedProject else { return }
              do { try store.setProjectCover(id, projectID: project.id); coverRevision += 1 }
              catch { errorMessage = error.localizedDescription }
            }.id("\(selectedProject?.id.uuidString ?? "")-\(coverRevision)")
          }
        }
      }
      .overlay { if dropTargeted { Rectangle().stroke(.white, lineWidth: 3).allowsHitTesting(false) } }
      .dropDestination(for: URL.self) { urls, _ in
        guard !library.isImporting, urls.allSatisfy(\.isFileURL), !urls.isEmpty else { return false }
        importURLs = urls; showImportSheet = true; return true
      } isTargeted: { dropTargeted = $0 }
    }
  }

  private var currentCoverID: UUID? {
    guard let project = selectedProject else { return nil }
    return (try? store.projectOverview(project.id))?.cover?.id
  }

  private var fixtureCanvas: some View {
    VStack(spacing: 24) {
      ZStack {
        Rectangle().fill(Color(white: 0.12))
        Rectangle().fill(Color(white: 0.35)).rotationEffect(.degrees(35)).frame(width: 150, height: 300)
        Circle().fill(Color(white: 0.85)).frame(width: 130).offset(x: 60, y: -30)
      }.frame(maxWidth: 680, maxHeight: 420).clipped().padding(32)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(workspace.selectedAssetID == fixtureID ? Color.white : Color.clear))
        .onTapGesture { workspace.selectedAssetID = fixtureID }
        .accessibilityElement(children: .ignore).accessibilityLabel("Abstract development study").accessibilityAddTraits(.isButton)
        .accessibilityAction { workspace.selectedAssetID = fixtureID }
      if !workspace.isFocused { Text("Development study · fixture artwork").font(.caption).foregroundStyle(.secondary) }
    }
  }

  // MARK: Inspector

  @ViewBuilder private var inspector: some View {
    if demo {
      ContentUnavailableView("Development Fixture", systemImage: "photo", description: Text("Abstract test artwork. Disable fixtures to return to your photographs."))
    } else if workspace.mode == .edit {
      EditInspector(library: library)
    } else {
      PhotoMetadataInspector(library: library)
    }
  }

  // MARK: Sheets and actions

  private var projectSheet: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(editingProject == nil ? "New Project" : "Rename Project").font(.title2)
      TextField("Project name", text: $projectTitle).textFieldStyle(.roundedBorder).onSubmit(saveProject)
      HStack {
        Spacer()
        Button("Cancel") { showProjectSheet = false }.keyboardShortcut(.cancelAction)
        Button("Save", action: saveProject).keyboardShortcut(.defaultAction)
          .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 380)
  }
  private var collectionSheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(editingCollectionID == nil ? "New Collection" : "Rename Collection").font(.headline)
      TextField("Collection name", text: $collectionTitle).textFieldStyle(.roundedBorder)
      Text("Collections organise this project’s photographs without moving originals.").font(.caption).foregroundStyle(.secondary)
      HStack {
        Button("Cancel") { showCollectionSheet = false }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save") {
          if let editingCollectionID { library.renameCollection(editingCollectionID, title: collectionTitle) }
          else { library.createCollection(title: collectionTitle) }
          showCollectionSheet = false
        }.keyboardShortcut(.defaultAction).disabled(collectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(24).frame(width: 360)
  }
  private func presentImport() {
    guard !library.isImporting else { return }
    importURLs = []; showImportSheet = true
  }
  private func presentExport() {
    guard !library.exporter.isRunning else { return }
    if library.actionableIDs.isEmpty { errorMessage = "Select the photographs to export in Library or Cull first."; return }
    showExportSheet = true
  }
  private func saveProject() {
    do {
      if let editingProject { try store.rename(editingProject, title: projectTitle) }
      else { workspace.selectedProjectID = try store.create(title: projectTitle).id }
      showProjectSheet = false
    } catch { errorMessage = error.localizedDescription }
  }
  private var emptyTitle: String {
    switch workspace.mode {
    case .library: selectedProject == nil ? "A place for your next shoot" : "Your project is ready"
    case .cull: "No photographs to review"
    case .edit: "No photograph to edit"
    case .publish: "Nothing to publish yet"
    }
  }
  private var emptyDescription: String {
    switch workspace.mode {
    case .library: "Drop files or folders here, or choose Import Photographs to begin. Originals are never changed."
    case .cull: "Import photographs into Library to rate, flag and review them here."
    case .edit: "Choose a photograph in Library to edit it. Originals are never changed."
    case .publish: "Publishing is not connected in this build."
    }
  }
}
