import SwiftUI
import AppKit

public struct EditWorkspace: View {
  let library: LibraryController
  let isFocused: Bool
  private var editor: EditController { library.editor }
  public init(library: LibraryController, isFocused: Bool) { self.library = library; self.isFocused = isFocused }
  public var body: some View {
    VStack(spacing: 16) {
      if let error = editor.loadError ?? editor.saveError {
        Text(error).font(.callout).textSelection(.enabled)
        Button("Retry saved edits") { editor.retry(); editor.open(library.activePhoto) }
      }
      if let error = editor.renderError {
        ContentUnavailableView {
          Label("Cannot render photograph", systemImage: "photo.badge.exclamationmark")
        } description: { Text(error) } actions: {
          Button("Retry rendering") { editor.requestPreview() }
        }
      } else if let image = editor.previewImage {
        Image(decorative: image, scale: 1).resizable().scaledToFit().accessibilityHidden(false).accessibilityLabel("Edited preview of \(editor.photo?.filename ?? "photograph")")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .overlay(alignment: .topTrailing) { if editor.isRendering { ProgressView("Updating preview…").padding(8).background(.regularMaterial) } }
      } else if editor.isRendering {
        ProgressView("Rendering photograph…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView("Select a photograph", systemImage: "photo")
      }
      if !isFocused, let recipe = editor.history?.current {
        VStack(spacing: 12) {
          HStack {
            Text(editor.photo?.filename ?? "").font(.caption).lineLimit(1)
            Spacer()
            Text(editor.isSaved ? "Saved · revision \(recipe.revision)" : "Unsaved edits").font(.caption).foregroundStyle(.secondary)
          }
          parameter("Exposure", path: \.exposure, range: -5...5, value: recipe.exposure)
          parameter("Contrast", path: \.contrast, range: -1...1, value: recipe.contrast)
          parameter("Saturation", path: \.saturation, range: 0...2, value: recipe.saturation)
          HStack {
            Button("Undo edit") { editor.undo() }.disabled(editor.history?.undo.isEmpty != false)
            Button("Redo edit") { editor.redo() }.disabled(editor.history?.redo.isEmpty != false)
            Spacer()
            Button("Reset adjustments") { editor.reset() }
          }
          Text("Exposure, contrast and saturation are ready. More editing tools follow in the next milestone.")
            .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: 640)
      }
    }.padding(isFocused ? 0 : 20)
      .onAppear { editor.activate(library.activePhoto) }
      .onChange(of: library.activePhoto) { _, photo in editor.open(photo) }
      .onDisappear { editor.deactivate() }
  }
  private func parameter(_ name: String, path: WritableKeyPath<EditRecipe, Double>, range: ClosedRange<Double>, value: Double) -> some View {
    HStack {
      Text(name).frame(width: 80, alignment: .leading)
      Slider(value: Binding(get: { editor.history?.current[keyPath: path] ?? value }, set: { editor.set(path, value: $0) }), in: range,
        onEditingChanged: { active in if active { editor.beginGesture() } else { editor.finishGesture() } })
        .accessibilityLabel(name)
      Text(value.formatted(.number.precision(.fractionLength(2)))).monospacedDigit().frame(width: 48)
    }
  }
}
