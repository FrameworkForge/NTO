import SwiftUI
import AppKit

/// Edit mode canvas: the rendered recipe result with a floating tool bar. Every adjustment lives in `EditInspector`.
/// Views only read `EditController` state and call its methods; no Core Image or database work happens here.
public struct EditWorkspace: View {
  let library: LibraryController
  let isFocused: Bool
  private var editor: EditController { library.editor }
  public init(library: LibraryController, isFocused: Bool) { self.library = library; self.isFocused = isFocused }
  public var body: some View {
    ZStack {
      Color.black
      preview
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      HStack(spacing: 8) {
        if let photo = editor.photo { Text(photo.filename).font(.caption).foregroundStyle(.secondary) }
        if editor.isComparing { CanvasBadge(text: "Original", prominent: true) }
        if editor.isPreviewingAdjustments { CanvasBadge(text: "Preset preview") }
        if editor.cropSession != nil { CanvasBadge(text: "Crop · Return applies, Escape cancels") }
        if editor.isInspecting { CanvasBadge(text: "100% · Space or Escape to leave") }
        if editor.isSamplingWhiteBalance { CanvasBadge(text: "Click a neutral grey or white · Escape cancels") }
      }.padding(14)
    }
    .overlay(alignment: .topTrailing) {
      VStack(alignment: .trailing, spacing: 6) {
        if editor.isRendering || editor.isRenderingFull { ProgressView("Updating…").controlSize(.small).padding(8).background(.regularMaterial, in: .rect(cornerRadius: 6)) }
        if let error = editor.loadError ?? editor.saveError {
          VStack(alignment: .trailing, spacing: 4) {
            Text(error).font(.caption).multilineTextAlignment(.trailing).frame(maxWidth: 320)
            Button("Retry saved edits") { editor.retry(); editor.open(library.activePhoto) }.controlSize(.small)
          }.padding(8).background(.regularMaterial, in: .rect(cornerRadius: 6))
        }
        if let error = editor.sampleError {
          Text("White balance sample: \(error)").font(.caption).frame(maxWidth: 320).padding(8).background(.regularMaterial, in: .rect(cornerRadius: 6))
        }
      }.padding(14)
    }
    .overlay { if editor.isStraightening { StraightenGuide().padding(isFocused ? 0 : 32).allowsHitTesting(false) } }
    .overlay(alignment: .bottom) { if editor.history != nil { toolBar.padding(.bottom, 16) } }
    // Escape, Return, Space and backslash route through the window monitor, bypassing text fields and sheets like Cull.
    .background(CullKeyboardShortcuts { event in
      switch event.keyCode {
      case 53:
        if editor.cropSession != nil { editor.cancelCrop() }
        else if editor.isSamplingWhiteBalance { editor.isSamplingWhiteBalance = false }
        else if editor.isInspecting { editor.setInspecting(false) }
        else { return false }
      case 36, 76:
        guard editor.cropSession != nil else { return false }
        editor.commitCrop()
      case 49:
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
      }.padding(isFocused ? 0 : 32)
    } else if editor.isComparing, let photo = editor.photo {
      PhotoThumbnail(photo: photo, previews: library.previews, size: 2000)
        .accessibilityElement(children: .contain).accessibilityLabel("Original preview of \(photo.filename)")
        .padding(isFocused ? 0 : 32)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { editor.isComparing = $0 }, perform: {})
    } else if editor.isPreviewingAdjustments, let image = editor.adjustmentPreviewImage {
      Image(decorative: image, scale: 1).resizable().scaledToFit()
        .accessibilityHidden(false).accessibilityLabel("Preset preview of \(editor.photo?.filename ?? "photograph")")
        .padding(isFocused ? 0 : 32)
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
      }.padding(isFocused ? 0 : 32)
        .help(editor.isSamplingWhiteBalance ? "Click a point that should be neutral" : "Press and hold to see the original")
    } else if editor.isRendering {
      ProgressView("Rendering photograph…")
    } else {
      ContentUnavailableView("Select a photograph", systemImage: "photo", description: Text("Choose a photograph in Library or Cull. Adjustments appear in the inspector."))
    }
  }

  private var toolBar: some View {
    HStack(spacing: 6) {
      Toggle("Original", isOn: Binding(get: { editor.isComparing }, set: { editor.isComparing = $0 }))
        .toggleStyle(.button).disabled(editor.cropSession != nil || editor.isInspecting).help("Compare with the original (\\), or press and hold the photograph")
      Toggle(editor.isInspecting ? "Fit" : "100%", isOn: Binding(get: { editor.isInspecting }, set: { editor.setInspecting($0) }))
        .toggleStyle(.button).disabled(editor.cropSession != nil).help("One image pixel per display pixel (Space)")
      if editor.cropSession != nil {
        Button("Apply Crop") { editor.commitCrop() }.keyboardShortcut(.defaultAction)
        Button("Cancel") { editor.cancelCrop() }
      } else {
        Button("Crop") { editor.beginCrop() }.disabled(editor.previewImage == nil || editor.isInspecting)
      }
      Toggle(isOn: Binding(get: { editor.isSamplingWhiteBalance }, set: { editor.isSamplingWhiteBalance = $0 })) {
        Image(systemName: "eyedropper")
      }.toggleStyle(.button).disabled(editor.cropSession != nil || editor.isInspecting)
        .accessibilityLabel("White balance eyedropper").help("Click a neutral area to set white balance")
      Divider().frame(height: 16)
      Button("Undo") { editor.undo() }.disabled(editor.history?.undo.isEmpty != false)
      Button("Redo") { editor.redo() }.disabled(editor.history?.redo.isEmpty != false)
    }
    .floatingBar()
  }
}
