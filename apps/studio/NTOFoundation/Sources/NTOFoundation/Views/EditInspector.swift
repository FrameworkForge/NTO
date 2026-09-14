import SwiftUI

/// The Edit inspector: presets and sync, then Light, Colour, Detail and Geometry as collapsible grouped sections.
public struct EditInspector: View {
  let library: LibraryController
  private var editor: EditController { library.editor }
  @State private var expanded: Set<EditGroup> = [.light, .colour]
  public init(library: LibraryController) { self.library = library }

  public var body: some View {
    if let recipe = editor.history?.current {
      Form {
        EditPresetsSection(library: library)
        group(.light, recipe) {
          parameter("Exposure", path: \.exposure, range: -5...5, step: 0.01, unit: "EV")
          parameter("Contrast", path: \.contrast, range: -1...1, step: 0.01)
          parameter("Highlights", path: \.highlights, range: -1...1, step: 0.01)
          parameter("Shadows", path: \.shadows, range: -1...1, step: 0.01)
          parameter("Whites", path: \.whites, range: -1...1, step: 0.01)
          parameter("Blacks", path: \.blacks, range: -1...1, step: 0.01)
        }
        group(.colour, recipe) {
          whiteBalance(recipe)
          parameter("Tint", path: \.tint, range: -150...150, step: 1)
          parameter("Vibrance", path: \.vibrance, range: -1...1, step: 0.01)
          parameter("Saturation", path: \.saturation, range: 0...2, step: 0.01)
        }
        group(.detail, recipe) {
          parameter("Sharpness", path: \.sharpness, range: 0...2, step: 0.01)
          parameter("Noise Reduction", path: \.noiseReduction, range: 0...1, step: 0.01)
        }
        group(.geometry, recipe) {
          geometry(recipe)
        }
        Section {
          HStack {
            Text(editor.isSaved ? "Saved · revision \(recipe.revision)" : "Unsaved edits").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Reset All") { editor.reset() }.controlSize(.small)
              .disabled(recipe.hasSameAdjustments(as: .neutral(assetID: recipe.assetId)))
          }
        }
      }
      .formStyle(.grouped)
    } else if let error = editor.loadError {
      ContentUnavailableView { Label("Saved edits could not open", systemImage: "exclamationmark.triangle") } description: { Text(error) } actions: {
        Button("Retry") { editor.retry(); editor.open(library.activePhoto) }
      }
    } else {
      ContentUnavailableView("No Photograph", systemImage: "slider.horizontal.3", description: Text("Choose a photograph to edit."))
    }
  }

  private func group<Content: View>(_ group: EditGroup, _ recipe: EditRecipe, @ViewBuilder content: @escaping () -> Content) -> some View {
    Section(isExpanded: Binding(get: { expanded.contains(group) }, set: { if $0 { expanded.insert(group) } else { expanded.remove(group) } })) {
      content()
    } header: {
      HStack {
        Text(group.rawValue)
        Spacer()
        Button("Reset") { editor.reset(group) }.buttonStyle(.plain).font(.caption)
          .foregroundStyle(recipe.isNeutral(group) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
          .disabled(recipe.isNeutral(group)).accessibilityLabel("Reset \(group.rawValue)")
      }
    }
  }

  private func gesture(_ active: Bool) { if active { editor.beginGesture() } else { editor.finishGesture() } }

  private func parameter(_ name: String, path: WritableKeyPath<EditRecipe, Double>, range: ClosedRange<Double>, step: Double, unit: String? = nil) -> some View {
    let current = editor.history?.current[keyPath: path] ?? 0
    return HStack(spacing: 8) {
      Text(name).font(.callout).frame(width: 90, alignment: .leading)
      Slider(value: Binding(get: { editor.history?.current[keyPath: path] ?? current }, set: { editor.set(path, value: $0) }),
        in: range, onEditingChanged: gesture)
        .accessibilityLabel(name)
      numericField(name, value: current, range: range, step: step, unit: unit) { editor.set(path, value: $0) }
    }
  }

  /// Numeric entry commits on Return or focus loss as one undoable change, clamped to the field's range.
  private func numericField(_ name: String, value: Double, range: ClosedRange<Double>, step: Double, unit: String? = nil,
    commit: @escaping (Double) -> Void) -> some View {
    let digits = step >= 1 ? 0 : 2
    return TextField(name, value: Binding(get: { value }, set: { commit(min(max($0, range.lowerBound), range.upperBound)) }),
      format: .number.precision(.fractionLength(digits)))
      .textFieldStyle(.plain).multilineTextAlignment(.trailing).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      .frame(width: 52).labelsHidden().accessibilityLabel("\(name) value" + (unit.map { " in \($0)" } ?? ""))
  }

  @ViewBuilder private func whiteBalance(_ recipe: EditRecipe) -> some View {
    if let kelvin = recipe.temperature {
      HStack(spacing: 8) {
        Text("Temperature").font(.callout).frame(width: 90, alignment: .leading)
        Slider(value: Binding(get: { editor.history?.current.temperature ?? kelvin }, set: { editor.setTemperature($0) }),
          in: 2000...max(20000, kelvin), onEditingChanged: gesture).accessibilityLabel("Temperature")
        numericField("Temperature", value: kelvin, range: 2000...50000, step: 1, unit: "K") { editor.setTemperature($0) }
      }
      HStack {
        Spacer().frame(width: 90)
        Button("Use As Shot") { editor.setTemperature(nil) }.controlSize(.small)
          .help("Return to the camera's white balance for RAW, or the file's existing appearance for other images")
        Button("Eyedropper") { editor.isSamplingWhiteBalance = true }.controlSize(.small)
        Spacer()
      }
    } else {
      HStack(spacing: 8) {
        Text("Temperature").font(.callout).frame(width: 90, alignment: .leading)
        Text("As Shot").foregroundStyle(.secondary)
        Spacer()
        Button("Adjust") { editor.setTemperature(6500) }.controlSize(.small)
          .help("Set an explicit Kelvin value. 6500 K leaves a non-RAW image unchanged.")
        Button("Eyedropper") { editor.isSamplingWhiteBalance = true }.controlSize(.small)
          .help("Click a neutral area of the photograph to set temperature and tint")
      }
    }
  }

  @ViewBuilder private func geometry(_ recipe: EditRecipe) -> some View {
    HStack(spacing: 8) {
      Text("Rotation").font(.callout).frame(width: 90, alignment: .leading)
      Slider(value: Binding(get: { editor.history?.current.rotation ?? recipe.rotation }, set: { editor.setRotation($0) }),
        in: -180...180, onEditingChanged: gesture).accessibilityLabel("Rotation")
      numericField("Rotation", value: recipe.rotation, range: -180...180, step: 0.1, unit: "degrees") { editor.setRotation($0) }
    }
    HStack {
      Spacer().frame(width: 90)
      Button { editor.rotate(by: -90) } label: { Label("Rotate Left", systemImage: "rotate.left") }.controlSize(.small)
      Button { editor.rotate(by: 90) } label: { Label("Rotate Right", systemImage: "rotate.right") }.controlSize(.small)
      Spacer()
    }
    if let session = editor.cropSession {
      LabeledContent("Aspect") {
        Picker("Aspect", selection: Binding(get: { session.aspect }, set: { editor.setCropAspect($0, portrait: session.portrait) })) {
          ForEach(CropAspect.allCases) { Text($0.title).tag($0) }
        }.labelsHidden().fixedSize()
      }
      Toggle("Portrait", isOn: Binding(get: { session.portrait }, set: { editor.setCropAspect(session.aspect, portrait: $0) }))
        .disabled(session.aspect == .free || session.aspect == .square)
      cropFields(session.pending) { editor.updateCrop($0) }
      Text("Drag the rectangle over the uncropped photograph. Return applies, Escape cancels. Rotation applies after the crop.")
        .font(.caption).foregroundStyle(.secondary)
    } else {
      cropFields(recipe.crop) { editor.setCrop($0) }
      HStack {
        Spacer().frame(width: 90)
        Button("Crop Tool") { editor.beginCrop() }.controlSize(.small).disabled(editor.previewImage == nil || editor.isInspecting)
        Spacer()
      }
    }
  }

  private func cropFields(_ crop: EditRecipeCrop, commit: @escaping (EditRecipeCrop) -> Void) -> some View {
    HStack(spacing: 6) {
      Text("Crop").font(.callout).frame(width: 90, alignment: .leading)
      cropField("Left", crop.x) { commit(EditRecipeCrop(x: $0, y: crop.y, width: crop.width, height: crop.height)) }
      cropField("Top", crop.y) { commit(EditRecipeCrop(x: crop.x, y: $0, width: crop.width, height: crop.height)) }
      cropField("Width", crop.width) { commit(EditRecipeCrop(x: crop.x, y: crop.y, width: $0, height: crop.height)) }
      cropField("Height", crop.height) { commit(EditRecipeCrop(x: crop.x, y: crop.y, width: crop.width, height: $0)) }
    }
  }
  private func cropField(_ name: String, _ value: Double, commit: @escaping (Double) -> Void) -> some View {
    VStack(spacing: 1) {
      TextField(name, value: Binding(get: { value }, set: { commit($0) }), format: .number.precision(.fractionLength(3)))
        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).font(.caption.monospacedDigit()).frame(width: 52)
        .labelsHidden().accessibilityLabel("Crop \(name.lowercased())")
      Text(name).font(.caption2).foregroundStyle(.secondary)
    }
  }
}
