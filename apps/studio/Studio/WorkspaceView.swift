import NTOFoundation
import SwiftUI

struct WorkspaceView: View {
  @Bindable var workspace: WorkspaceState
  @Bindable var store: ProjectStore
  @State private var showProjectSheet = false
  @State private var editingProject: LocalProject?
  @State private var projectTitle = ""
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
            ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(store.projects, id: \.id) { project in
                  Button {
                    workspace.selectedProjectID = project.id
                  } label: {
                    Text(project.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                      .padding(8).background(
                        workspace.selectedProjectID == project.id
                          ? Color.white.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 4))
                  }.buttonStyle(.plain).contextMenu {
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
              .onChange(of: demo) { _, enabled in if !enabled { workspace.selectedAssetID = nil } }
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
            } else {
              ContentUnavailableView {
                Label(emptyTitle, systemImage: workspace.mode.symbol)
              } description: {
                Text(emptyDescription)
              } actions: {
                if workspace.mode == .library {
                  Button("New Project") {
                    editingProject = nil
                    projectTitle = ""
                    showProjectSheet = true
                  }
                }
              }
            }
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        if workspace.inspectorVisible && geometry.size.width >= 1000 {
          Divider()
          VStack(alignment: .leading, spacing: 16) {
            Text("INSPECTOR").font(.caption).foregroundStyle(.secondary)
            Text(workspace.selectedAssetID == nil ? "No photograph selected" : "Development study")
            Text("Metadata and editing controls will appear here as those features are added.")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
          }.padding(20).frame(width: 230)
        }
      }
    }
    .frame(minWidth: 700, minHeight: 500).background(NTOTokens.Color.canvas).preferredColorScheme(
      .dark
    )
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
      "Project could not be saved",
      isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    ) {
      Button("OK") { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "Try saving again.")
    }
    .onChange(of: workspace.newProjectRequested) { _, _ in
      editingProject = nil
      projectTitle = ""
      showProjectSheet = true
    }
    .onAppear {
      if workspace.selectedProjectID == nil {
        workspace.selectedProjectID = store.projects.first?.id
      }
    }
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
    case .library: "Create and organise projects. Photo import is coming in the next milestone."
    case .cull: "Culling will become available once photographs can be imported."
    case .edit: "The rendering boundary is ready. Editing tools are a later milestone."
    case .publish: "Cloud publishing is not connected in this foundation build."
    }
  }
}
