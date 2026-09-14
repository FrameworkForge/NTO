import SwiftUI
import AppKit

/// Edit mode: the rendered recipe result above progressively disclosed Light, Colour, Detail and Geometry groups.
/// Views only read `EditController` state and call its methods; no Core Image or database work happens here.
public struct EditWorkspace: View {
  let library: LibraryController
  let isFocused: Bool
  private var editor: EditController { library.editor }
  @State private var expanded: Set<EditGroup> = [.light]
  public init(library: LibraryController, isFocused: Bool) { self.library = library; self.isFocused = isFocused }
  public var body: some View {
    VStack(spacing: 16) {
      if let error = editor.loadError ?? editor.saveError {
        Text(error).font(.callout).textSelection(.enabled)
        Button("Retry saved edits") { editor.retry(); editor.open(library.activePhoto) }
      }
      if let error = editor.sampleError { Text("White balance sample: \(error)").font(.caption).foregroundStyle(.secondary) }
      preview
      if !isFocused, let recipe = editor.history?.current {
        controls(recipe)
      }
    }.padding(isFocused ? 0 : 20)
      // Backslash toggles the original, bypassing text fields and sheets like Cull's shortcuts.
      .background(CullKeyboardShortcuts { event in
        switch event.keyCode {
        case 53:  // Escape leaves the current tool without changing the recipe.
          if editor.cropSession != nil { editor.cancelCrop() }
          else if editor.isSamplingWhiteBalance { editor.isSamplingWhiteBalance = false }
          else if editor.isInspecting { editor.setInspecting(false) }
          else { return false }
        case 36, 76:  // Return commits a crop.
          guard editor.cropSession != nil else { return false }
          editor.commitCrop()
        case 49:  // Space toggles 100% inspection, as in Cull.
          guard !event.isARepeat, editor.cropSession == nil else { return false }
          editor.setInspecting(!editor.isInspecting)
        default:
          guard event.charactersIgnoringModifiers == "\\" else { return false }
          editor.isComparing.toggle()
        }
        return true
      }.frame(width: 0, height: 0))
      .onAppear { editor.activate(library.activePhoto) }
      .onChange(of: library.activePhoto) { _, photo in editor.open(photo) }
      .onDisappear { editor.deactivate() }
  }

  @ViewBuilder private var preview: some View {
    if editor.isInspecting {
      EditPixelInspection(editor: editor)
        .overlay(alignment: .topLeading) { badge("100% · Space or Escape to leave") }
    } else if let session = editor.cropSession, let image = editor.previewImage, let photo = editor.photo {
      GeometryReader { proxy in
        let displayed = CropGeometry.fittedRect(imageSize: CGSize(width: image.width, height: image.height), in: proxy.size)
        ZStack {
          Image(decorative: image, scale: 1).resizable().scaledToFit()
            .accessibilityHidden(false).accessibilityLabel("Uncropped preview of \(photo.filename) for cropping")
          CropOverlay(displayed: displayed, crop: session.pending,
            heightFactor: CropGeometry.heightFactor(aspect: session.aspect, portrait: session.portrait, imageSize: CGSize(width: photo.width, height: photo.height)),
            onChange: { editor.updateCrop($0) })
        }.frame(width: proxy.size.width, height: proxy.size.height)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { badge("Crop · Return applies, Escape cancels") }
        .overlay(alignment: .topTrailing) { if editor.isRendering { ProgressView("Updating preview…").padding(8).background(.regularMaterial) } }
    } else if editor.isComparing, let photo = editor.photo {
      PhotoThumbnail(photo: photo, previews: library.previews, size: 2000)
        .accessibilityElement(children: .contain).accessibilityLabel("Original preview of \(photo.filename)")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { badge("Original") }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { editor.isComparing = $0 }, perform: {})
    } else if editor.isPreviewingAdjustments, let image = editor.adjustmentPreviewImage {
      Image(decorative: image, scale: 1).resizable().scaledToFit()
        .accessibilityHidden(false).accessibilityLabel("Preset preview of \(editor.photo?.filename ?? "photograph")")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { badge("Preset preview") }
    } else if let error = editor.renderError {
      ContentUnavailableView {
        Label("Cannot render photograph", systemImage: "photo.badge.exclamationmark")
      } description: { Text(error) } actions: {
        Button("Retry rendering") { editor.requestPreview() }
      }
    } else if let image = editor.previewImage {
      GeometryReader { proxy in
        let displayed = CropGeometry.fittedRect(imageSize: CGSize(width: image.width, height: image.height), in: proxy.size)
        Image(decorative: image, scale: 1).resizable().scaledToFit()
          .accessibilityHidden(false).accessibilityLabel("Edited preview of \(editor.photo?.filename ?? "photograph")")
          .frame(width: proxy.size.width, height: proxy.size.height)
          .onTapGesture { location in
            guard editor.isSamplingWhiteBalance, displayed.contains(location) else { return }
            let point = CGPoint(x: (location.x - displayed.minX) / displayed.width, y: (location.y - displayed.minY) / displayed.height)
            Task { await editor.sampleWhiteBalance(at: point) }
          }
          .onLongPressGesture(minimumDuration: .infinity, pressing: { if !editor.isSamplingWhiteBalance { editor.isComparing = $0 } }, perform: {})
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { if editor.isRendering { ProgressView("Updating preview…").padding(8).background(.regularMaterial) } }
        .overlay(alignment: .topLeading) { if editor.isSamplingWhiteBalance { badge("Click a neutral grey or white · Escape cancels") } }
        .help(editor.isSamplingWhiteBalance ? "Click a point that should be neutral" : "Press and hold to see the original")
    } else if editor.isRendering {
      ProgressView("Rendering photograph…").frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ContentUnavailableView("Select a photograph", systemImage: "photo")
    }
  }

  private func badge(_ text: String) -> some View {
    Text(text).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(.regularMaterial).padding(8)
  }

  private func controls(_ recipe: EditRecipe) -> some View {
    VStack(spacing: 12) {
      HStack {
        Text(editor.photo?.filename ?? "").font(.caption).lineLimit(1)
        Spacer()
        Text(editor.isSaved ? "Saved · revision \(recipe.revision)" : "Unsaved edits").font(.caption).foregroundStyle(.secondary)
      }
      HStack {
        Button("Undo edit") { editor.undo() }.disabled(editor.history?.undo.isEmpty != false)
        Button("Redo edit") { editor.redo() }.disabled(editor.history?.redo.isEmpty != false)
        Button(editor.isComparing ? "Show edit" : "Show original") { editor.isComparing.toggle() }
          .help("Toggle the original (\\), or press and hold the photograph").disabled(editor.cropSession != nil || editor.isInspecting)
        Button(editor.isInspecting ? "Fit" : "100%") { editor.setInspecting(!editor.isInspecting) }
          .help("Inspect the edited result at one image pixel per display pixel (Space)").disabled(editor.cropSession != nil)
        if editor.cropSession == nil {
          Button("Crop") { editor.beginCrop(); expanded.insert(.geometry) }.disabled(editor.previewImage == nil || editor.isInspecting)
        } else {
          Button("Apply crop") { editor.commitCrop() }.keyboardShortcut(.defaultAction)
          Button("Cancel crop") { editor.cancelCrop() }
        }
        Toggle(isOn: Binding(get: { editor.isSamplingWhiteBalance }, set: { editor.isSamplingWhiteBalance = $0 })) {
          Label("Eyedropper", systemImage: "eyedropper")
        }.toggleStyle(.button).help("Click a neutral area to set white balance").disabled(editor.cropSession != nil || editor.isInspecting)
        Spacer()
        Button("Reset all") { editor.reset() }.disabled(recipe.hasSameAdjustments(as: .neutral(assetID: recipe.assetId)))
      }
      EditPresetsBar(library: library)
      ScrollView {
        VStack(spacing: 8) {
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
            parameter("Noise reduction", path: \.noiseReduction, range: 0...1, step: 0.01)
          }
          group(.geometry, recipe) {
            geometry(recipe)
          }
        }
      }.frame(maxHeight: 300)
    }.frame(maxWidth: 720)
  }

  private func group<Content: View>(_ group: EditGroup, _ recipe: EditRecipe, @ViewBuilder content: @escaping () -> Content) -> some View {
    DisclosureGroup(isExpanded: Binding(
      get: { expanded.contains(group) },
      set: { if $0 { expanded.insert(group) } else { expanded.remove(group) } }
    )) {
      VStack(spacing: 8) { content() }.padding(.top, 6)
    } label: {
      HStack {
        Text(group.rawValue).font(.headline)
        Spacer()
        Button("Reset") { editor.reset(group) }.controlSize(.small).disabled(recipe.isNeutral(group))
          .accessibilityLabel("Reset \(group.rawValue)")
      }
    }
  }

  private func gesture(_ active: Bool) { if active { editor.beginGesture() } else { editor.finishGesture() } }

  private func parameter(_ name: String, path: WritableKeyPath<EditRecipe, Double>, range: ClosedRange<Double>, step: Double, unit: String? = nil) -> some View {
    let current = editor.history?.current[keyPath: path] ?? 0
    return HStack {
      Text(name).frame(width: 110, alignment: .leading)
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
    return HStack(spacing: 4) {
      TextField(name, value: Binding(get: { value }, set: { commit(min(max($0, range.lowerBound), range.upperBound)) }),
        format: .number.precision(.fractionLength(digits)))
        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).monospacedDigit().frame(width: 72)
        .labelsHidden().accessibilityLabel("\(name) value")
      if let unit { Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 22, alignment: .leading) }
      else { Spacer().frame(width: 22) }
    }
  }

  @ViewBuilder private func whiteBalance(_ recipe: EditRecipe) -> some View {
    if let kelvin = recipe.temperature {
      HStack {
        Text("Temperature").frame(width: 110, alignment: .leading)
        Slider(value: Binding(get: { editor.history?.current.temperature ?? kelvin }, set: { editor.setTemperature($0) }),
          in: 2000...max(20000, kelvin), onEditingChanged: gesture)
          .accessibilityLabel("Temperature")
        numericField("Temperature", value: kelvin, range: 2000...50000, step: 1, unit: "K") { editor.setTemperature($0) }
      }
      HStack {
        Spacer().frame(width: 110)
        Button("Use as shot") { editor.setTemperature(nil) }.controlSize(.small)
          .help("Return to the camera's white balance for RAW, or the file's existing appearance for other images")
        Spacer()
      }
    } else {
      HStack {
        Text("Temperature").frame(width: 110, alignment: .leading)
        Text("As shot").foregroundStyle(.secondary)
        Spacer()
        Button("Adjust") { editor.setTemperature(6500) }.controlSize(.small)
          .help("Set an explicit Kelvin value. 6500 K leaves a non-RAW image unchanged.")
        Button("Eyedropper") { editor.isSamplingWhiteBalance = true }.controlSize(.small)
          .help("Click a neutral area of the photograph to set temperature and tint")
      }
    }
  }

  @ViewBuilder private func geometry(_ recipe: EditRecipe) -> some View {
    HStack {
      Text("Rotation").frame(width: 110, alignment: .leading)
      Slider(value: Binding(get: { editor.history?.current.rotation ?? recipe.rotation }, set: { editor.setRotation($0) }),
        in: -180...180, onEditingChanged: gesture)
        .accessibilityLabel("Rotation")
      numericField("Rotation", value: recipe.rotation, range: -180...180, step: 0.1, unit: "°") { editor.setRotation($0) }
    }
    HStack {
      Spacer().frame(width: 110)
      Button { editor.rotate(by: -90) } label: { Label("Rotate left", systemImage: "rotate.left") }.controlSize(.small)
      Button { editor.rotate(by: 90) } label: { Label("Rotate right", systemImage: "rotate.right") }.controlSize(.small)
      Spacer()
    }
    if let session = editor.cropSession {
      HStack {
        Text("Aspect").frame(width: 110, alignment: .leading)
        Picker("Aspect", selection: Binding(get: { session.aspect }, set: { editor.setCropAspect($0, portrait: session.portrait) })) {
          ForEach(CropAspect.allCases) { Text($0.title).tag($0) }
        }.labelsHidden().frame(width: 130)
        Toggle("Portrait", isOn: Binding(get: { session.portrait }, set: { editor.setCropAspect(session.aspect, portrait: $0) }))
          .disabled(session.aspect == .free || session.aspect == .square)
        Spacer()
      }
      HStack {
        Text("Crop").frame(width: 110, alignment: .leading)
        cropField("Left", session.pending.x) { editor.updateCrop(EditRecipeCrop(x: $0, y: session.pending.y, width: session.pending.width, height: session.pending.height)) }
        cropField("Top", session.pending.y) { editor.updateCrop(EditRecipeCrop(x: session.pending.x, y: $0, width: session.pending.width, height: session.pending.height)) }
        cropField("Width", session.pending.width) { editor.updateCrop(EditRecipeCrop(x: session.pending.x, y: session.pending.y, width: $0, height: session.pending.height)) }
        cropField("Height", session.pending.height) { editor.updateCrop(EditRecipeCrop(x: session.pending.x, y: session.pending.y, width: session.pending.width, height: $0)) }
      }
      HStack {
        Spacer().frame(width: 110)
        Text("Drag the rectangle or its edges over the uncropped photograph. Rotation is applied after the crop is committed.")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
      }
    } else {
      HStack {
        Text("Crop").frame(width: 110, alignment: .leading)
        cropField("Left", recipe.crop.x) { editor.setCrop(EditRecipeCrop(x: $0, y: recipe.crop.y, width: recipe.crop.width, height: recipe.crop.height)) }
        cropField("Top", recipe.crop.y) { editor.setCrop(EditRecipeCrop(x: recipe.crop.x, y: $0, width: recipe.crop.width, height: recipe.crop.height)) }
        cropField("Width", recipe.crop.width) { editor.setCrop(EditRecipeCrop(x: recipe.crop.x, y: recipe.crop.y, width: $0, height: recipe.crop.height)) }
        cropField("Height", recipe.crop.height) { editor.setCrop(EditRecipeCrop(x: recipe.crop.x, y: recipe.crop.y, width: recipe.crop.width, height: $0)) }
        Button("Crop tool") { editor.beginCrop() }.controlSize(.small).disabled(editor.previewImage == nil || editor.isInspecting)
      }
      HStack {
        Spacer().frame(width: 110)
        Text("Fractions of the oriented original; the crop is applied before rotation.")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
      }
    }
  }

  private func cropField(_ name: String, _ value: Double, commit: @escaping (Double) -> Void) -> some View {
    VStack(spacing: 2) {
      TextField(name, value: Binding(get: { value }, set: { commit($0) }), format: .number.precision(.fractionLength(3)))
        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).monospacedDigit().frame(width: 64)
        .labelsHidden().accessibilityLabel("Crop \(name.lowercased())")
      Text(name).font(.caption2).foregroundStyle(.secondary)
    }
  }
}
