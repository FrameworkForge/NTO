import SwiftUI

/// Shared native controls for the Studio workspace: star rating, flag segment, floating bars, pixel inspection.

struct RatingStars: View {
  let rating: Int
  let set: (Int) -> Void
  var body: some View {
    HStack(spacing: 2) {
      ForEach(1...5, id: \.self) { star in
        Button { set(star == rating ? 0 : star) } label: {
          Image(systemName: "star.fill").font(.system(size: 13))
            .foregroundStyle(star <= rating ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
        }.buttonStyle(.plain).accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
      }
    }
    .accessibilityElement(children: .contain).accessibilityLabel("Rating").accessibilityValue("\(rating) stars")
  }
}

struct FlagSegment: View {
  let flag: PhotoFlag
  let set: (PhotoFlag) -> Void
  var body: some View {
    Picker("Flag", selection: Binding(get: { flag }, set: set)) {
      Text("Pick").tag(PhotoFlag.pick)
      Text("None").tag(PhotoFlag.none)
      Text("Reject").tag(PhotoFlag.reject)
    }.pickerStyle(.segmented).labelsHidden().fixedSize()
  }
}

struct FlagDot: View {
  let flag: PhotoFlag
  var body: some View {
    if flag != .none {
      Circle().fill(flag == .pick ? AnyShapeStyle(.white) : AnyShapeStyle(.black.opacity(0.6)))
        .frame(width: 14, height: 14)
        .overlay { Circle().stroke(.white.opacity(0.35), lineWidth: 0.5) }
        .accessibilityLabel(flag == .pick ? "Picked" : "Rejected")
    }
  }
}

/// A floating control bar over the photograph, Liquid Glass on macOS 26.
struct FloatingBar: ViewModifier {
  func body(content: Content) -> some View {
    content.buttonStyle(.borderless).controlSize(.small).padding(6)
      .glassEffect(.regular, in: .rect(cornerRadius: 12))
  }
}
extension View { func floatingBar() -> some View { modifier(FloatingBar()) } }

/// A small pill over the photograph, for state such as "Original".
struct CanvasBadge: View {
  let text: String
  var prominent = false
  var body: some View {
    Text(text).font(.caption.weight(.semibold))
      .padding(.horizontal, 7).padding(.vertical, 2)
      .background(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.regularMaterial), in: .rect(cornerRadius: 5))
      .foregroundStyle(prominent ? .black : .primary)
  }
}

/// The original at one image pixel per display pixel, scrollable. Used by Cull.
struct PixelInspection: View {
  let photo: PhotoRecord
  let previews: PhotoPreviews
  @Environment(\.displayScale) private var displayScale
  @State private var image: CGImage?
  @State private var error: String?
  @State private var retry = 0
  var body: some View {
    Group {
      if let image {
        ScrollView([.horizontal, .vertical]) {
          Image(decorative: image, scale: displayScale)
            .resizable().interpolation(.none)
            .frame(width: CGFloat(image.width) / displayScale, height: CGFloat(image.height) / displayScale)
        }.defaultScrollAnchor(.center).accessibilityLabel("100 percent original, one image pixel per display pixel. Scroll to inspect.")
      } else if let error {
        ContentUnavailableView {
          Label("100% inspection unavailable", systemImage: "exclamationmark.triangle")
        } description: { Text(error) } actions: { Button("Retry") { retry += 1 } }
      } else { ProgressView("Loading original at 100%…") }
    }.task(id: "\(photo.id)-\(photo.locationRevision)-\(retry)") {
      image = nil; error = nil
      do {
        let decoded = try await previews.fullResolution(for: photo)
        if !Task.isCancelled { image = decoded }
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }.onDisappear { image = nil }
  }
}
