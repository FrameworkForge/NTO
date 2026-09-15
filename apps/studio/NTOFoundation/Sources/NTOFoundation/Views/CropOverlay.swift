import SwiftUI

/// Draggable crop rectangle over the uncropped preview. Handles resize, the interior moves, thirds guides show while dragging.
struct CropOverlay: View {
  let displayed: CGRect
  let crop: EditRecipeCrop
  let heightFactor: Double?
  let onChange: (EditRecipeCrop) -> Void
  @State private var active: CropHandle = .none
  @State private var start: EditRecipeCrop?
  private let tolerance: CGFloat = 12

  var body: some View {
    let rect = CropGeometry.viewRect(crop, in: displayed)
    ZStack {
      Path { path in
        path.addRect(displayed)
        path.addRect(rect)
      }.fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
      Path { path in
        path.addRect(rect)
        if start != nil {
          for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
          }
        }
      }.stroke(Color.white.opacity(0.9), lineWidth: 1)
      ForEach(corners(of: rect), id: \.0) { _, point in
        Rectangle().fill(Color.white).frame(width: 8, height: 8).position(point)
      }
    }
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
      if start == nil {
        start = crop
        active = CropGeometry.handle(at: value.startLocation, rect: rect, tolerance: tolerance)
      }
      guard let start, active != .none, displayed.width > 0, displayed.height > 0 else { return }
      onChange(CropGeometry.resize(start, handle: active,
        dx: value.translation.width / displayed.width, dy: value.translation.height / displayed.height, heightFactor: heightFactor))
    }.onEnded { _ in start = nil; active = .none })
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Crop rectangle")
    .accessibilityValue("Left \(Int(crop.x * 100)) percent, top \(Int(crop.y * 100)) percent, width \(Int(crop.width * 100)) percent, height \(Int(crop.height * 100)) percent. Use the crop fields to adjust with the keyboard.")
  }
  private func corners(of rect: CGRect) -> [(String, CGPoint)] {
    [("tl", CGPoint(x: rect.minX, y: rect.minY)), ("tr", CGPoint(x: rect.maxX, y: rect.minY)),
     ("bl", CGPoint(x: rect.minX, y: rect.maxY)), ("br", CGPoint(x: rect.maxX, y: rect.maxY))]
  }
}

/// The edited result at one image pixel per display pixel, scrollable.
struct EditPixelInspection: View {
  let editor: EditController
  @Environment(\.displayScale) private var displayScale
  var body: some View {
    if let image = editor.fullImage {
      ScrollView([.horizontal, .vertical]) {
        Image(decorative: image, scale: displayScale).resizable().interpolation(.none)
          .frame(width: CGFloat(image.width) / displayScale, height: CGFloat(image.height) / displayScale)
      }.defaultScrollAnchor(.center)
        .accessibilityLabel("100 percent edited result, one image pixel per display pixel. Scroll to inspect.")
        .overlay(alignment: .topTrailing) { if editor.isRenderingFull { ProgressView("Updating…").padding(8).background(.regularMaterial) } }
    } else if let error = editor.renderError {
      ContentUnavailableView { Label("100% inspection unavailable", systemImage: "exclamationmark.triangle") } description: { Text(error) } actions: {
        Button("Retry") { editor.requestFullResolution() }
      }
    } else {
      ProgressView("Rendering the full photograph…").frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

/// A level grid shown while the rotation slider is dragged, so horizons and verticals can be straightened by eye.
struct StraightenGuide: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      for step in 1..<10 {
        let x = size.width * CGFloat(step) / 10, y = size.height * CGFloat(step) / 10
        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
      var centre = Path()
      centre.move(to: CGPoint(x: 0, y: size.height / 2)); centre.addLine(to: CGPoint(x: size.width, y: size.height / 2))
      centre.move(to: CGPoint(x: size.width / 2, y: 0)); centre.addLine(to: CGPoint(x: size.width / 2, y: size.height))
      context.stroke(centre, with: .color(.white.opacity(0.8)), lineWidth: 1)
    }
    .accessibilityHidden(true)
  }
}
