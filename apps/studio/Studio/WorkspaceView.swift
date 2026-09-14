import AppKit
import UniformTypeIdentifiers
import NTOFoundation
import SwiftUI

struct WorkspaceView: View {
  @Bindable var workspace: WorkspaceState
  @Bindable var store: ProjectStore
  @Bindable var library: LibraryController
  @State private var showImportSheet = false
  @State private var importURLs: [URL] = []
  @State private var dropTargeted = false
  @AppStorage("lastProjectID") private var lastProjectID = ""
  @Environment(\.scenePhase) private var scenePhase
  @State private var showProjectSheet = false
  @State private var editingProject: LocalProject?
  @State private var projectTitle = ""
  @State private var projectSearch = ""
  @State private var coverRevision = 0
  @State private var errorMessage: String?
  @State private var demo = ProcessInfo.processInfo.arguments.contains("--fixtures")
  private let fixtureID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
  private var selectedProject: LocalProject? {
    store.projects.first { $0.id == workspace.selectedProjectID }
  }
  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        if workspace.sidebarVisible {
          VStack(alignment: .leading, spacing: NTOTokens.Spacing.lg) {
            Text("NTO STUDIO").font(.caption).foregroundStyle(NTOTokens.Color.muted)
            ForEach(StudioMode.allCases) { mode in
              Button {
                workspace.mode = mode
              } label: {
                Label(mode.rawValue, systemImage: mode.symbol).frame(
                  maxWidth: .infinity, alignment: .leading
                ).padding(8).background(
                  workspace.mode == mode ? Color.white.opacity(0.08) : .clear,
                  in: RoundedRectangle(cornerRadius: 6))
              }.buttonStyle(.plain)
            }
            Divider()
            HStack {
              Text("PROJECTS").font(.caption).foregroundStyle(.secondary)
              Spacer()
              Button {
                editingProject = nil
                projectTitle = ""
                showProjectSheet = true
              } label: {
                Image(systemName: "plus")
              }.help("New project").accessibilityLabel("New project")
            }
            TextField("Search projects", text: $projectSearch).textFieldStyle(.roundedBorder)
            ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(store.projects.filter { projectSearch.isEmpty || $0.title.localizedStandardContains(projectSearch) }, id: \.id) { project in
                  Button {
                    workspace.selectedProjectID = project.id
                  } label: {
                    ProjectSummaryLabel(project: project, store: store, library: library, revision: coverRevision)
                      .padding(8).background(
                        workspace.selectedProjectID == project.id
                          ? Color.white.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 4))
                  }.buttonStyle(.plain).contextMenu {
                    Button("Use selected photograph as cover") {
                      if let photo = library.activePhoto {
                        do { try store.setProjectCover(photo.id, projectID: project.id); coverRevision += 1 }
                        catch { errorMessage = error.localizedDescription }
                      }
                    }.disabled(library.projectID != project.id || library.activePhoto == nil)
                    Button("Rename Project") {
                      editingProject = project
                      projectTitle = project.title
                      showProjectSheet = true
                    }
                  }
                }
              }
            }
            Spacer()
            Toggle("Development fixtures", isOn: $demo).toggleStyle(.checkbox).font(.caption)
              .onChange(of: demo) { _, enabled in if !enabled { workspace.selectedAssetID = library.browsing.activeID } }
          }.padding(20).frame(width: 210)
          Divider()
        }
        VStack(spacing: 0) {
          if !workspace.isFocused {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(selectedProject?.title ?? workspace.mode.rawValue).font(.title2)
                Text(modeDescription).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Button("Import…") { presentImport() }.disabled(library.isImporting)
              if let project = selectedProject {
                Button("Rename") {
                  editingProject = project
                  projectTitle = project.title
                  showProjectSheet = true
                }
              }
            }.padding(24)
            Divider()
          }
          if !workspace.isFocused || library.isImporting {
            LibraryImportStatus(library: library)
          }
          ZStack {
            NTOTokens.Color.black
            if demo {
              VStack(spacing: 24) {
                ZStack {
                  Rectangle().fill(Color(white: 0.12))
                  Rectangle().fill(Color(white: 0.35)).rotationEffect(.degrees(35)).frame(
                    width: 150, height: 300)
                  Circle().fill(Color(white: 0.85)).frame(width: 130).offset(x: 60, y: -30)
                }.frame(maxWidth: 680, maxHeight: 420).clipped().padding(32).overlay(
                  RoundedRectangle(cornerRadius: 2).stroke(
                    workspace.selectedAssetID == fixtureID ? Color.white : Color.clear)
                ).onTapGesture { workspace.selectedAssetID = fixtureID }.accessibilityElement(
                  children: .ignore
                ).accessibilityLabel("Abstract development study").accessibilityAddTraits(.isButton)
                  .accessibilityAction { workspace.selectedAssetID = fixtureID }
                if !workspace.isFocused {
                  Text("Development study · fixture artwork").font(.caption).foregroundStyle(
                    .secondary)
                }
              }
            } else if !library.photos.isEmpty {
              if workspace.mode == .library {
                PhotoLibraryGrid(library: library, isFocused: workspace.isFocused) { workspace.mode = .cull }
                  .id(library.projectID)
              } else {
                SelectedPhotoCanvas(library: library, mode: workspace.mode, isFocused: workspace.isFocused)
              }
            } else {
              ContentUnavailableView {
                Label(emptyTitle, systemImage: workspace.mode.symbol)
              } description: {
                Text(emptyDescription)
              } actions: {
                if workspace.mode == .library {
                  Button("Import photographs…") { presentImport() }.disabled(library.isImporting)
                }
              }
            }
          }
          .overlay { if dropTargeted { Rectangle().stroke(.white, lineWidth: 3).allowsHitTesting(false) } }
          .dropDestination(for: URL.self) { urls, _ in
            guard !library.isImporting, urls.allSatisfy(\.isFileURL), !urls.isEmpty else { return false }
            importURLs = urls; showImportSheet = true; return true
          } isTargeted: { dropTargeted = $0 }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        if workspace.inspectorVisible && geometry.size.width >= 1000 {
          Divider()
          if demo {
            ContentUnavailableView("Development fixture", systemImage: "photo",
              description: Text("Abstract test artwork. Disable fixtures to return to your photographs."))
              .frame(width: 230)
          } else {
            PhotoMetadataInspector(library: library).frame(width: 230)
          }
        }
      }
    }
    .frame(minWidth: 700, minHeight: 500).background(NTOTokens.Color.canvas).preferredColorScheme(
      .dark
    ).tint(NTOTokens.Color.paper)
    .background(WorkspaceKeyboardShortcuts { workspace.toggleFocus() }.frame(width: 0, height: 0))
    .toolbar {
      ToolbarItem {
        Button {
          workspace.toggleFocus()
        } label: {
          Label(
            workspace.isFocused ? "Leave Focus Mode" : "Focus Mode",
            systemImage: workspace.isFocused
              ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }.help("Toggle Focus Mode (Tab)")
      }
    }
    .sheet(isPresented: $showImportSheet) {
      ImportPhotosSheet(library: library, store: store, initialURLs: importURLs) { id in
        demo = false
        workspace.selectedProjectID = id
        workspace.mode = .library
      }
    }
    .sheet(isPresented: $showProjectSheet) {
      VStack(alignment: .leading, spacing: 20) {
        Text(editingProject == nil ? "New Project" : "Rename Project").font(.title2)
        TextField("Project name", text: $projectTitle).textFieldStyle(.roundedBorder).onSubmit(
          saveProject)
        HStack {
          Spacer()
          Button("Cancel") { showProjectSheet = false }.keyboardShortcut(.cancelAction)
          Button("Save", action: saveProject).keyboardShortcut(.defaultAction).disabled(
            projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }.padding(28).frame(width: 380)
    }
    .alert(
      "Studio needs your attention",
      isPresented: Binding(get: { errorMessage != nil || library.errorMessage != nil }, set: { if !$0 { errorMessage = nil; library.errorMessage = nil } })
    ) {
      Button("OK") { errorMessage = nil; library.errorMessage = nil }
    } message: {
      Text(errorMessage ?? library.errorMessage ?? "Try again.")
    }
    .onChange(of: workspace.newProjectRequested) { _, _ in
      editingProject = nil
      projectTitle = ""
      showProjectSheet = true
    }
    .onChange(of: workspace.importRequested) { _, _ in presentImport() }
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
  private func presentImport() {
    guard !library.isImporting else { return }
    importURLs = []; showImportSheet = true
  }
  private func saveProject() {
    do {
      if let editingProject {
        try store.rename(editingProject, title: projectTitle)
      } else {
        workspace.selectedProjectID = try store.create(title: projectTitle).id
      }
      showProjectSheet = false
    } catch { errorMessage = error.localizedDescription }
  }
  private var modeDescription: String {
    switch workspace.mode {
    case .library: "Your photographic workspace"
    case .cull: "A space for the final selection"
    case .edit: "Non-destructive editing foundation"
    case .publish: "From Studio to the world"
    }
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
    case .library: "Drop files or folders here, or choose Import photographs to begin. Originals are never changed."
    case .cull: "Import photographs into Library to rate, flag and review them here."
    case .edit: "The rendering boundary is ready. Editing tools are a later milestone."
    case .publish: "Cloud publishing is not connected in this foundation build."
    }
  }
}
