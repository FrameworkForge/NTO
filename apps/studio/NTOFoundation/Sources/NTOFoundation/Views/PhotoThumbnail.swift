import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PhotoThumbnail: View {
  let photo: PhotoRecord
  let previews: PhotoPreviews
  var size: Int = 512
  @State private var image: CGImage?
  @State private var failure: String?
  @State private var retry = 0
  var body: some View {
    ZStack {
      Color(white: 0.055)
      if let image {
        Image(decorative: image, scale: 1).resizable().scaledToFit()
      } else if let failure {
        VStack(spacing: 8) {
          Image(systemName: "photo.badge.exclamationmark").font(.title2)
          Text(size > 512 ? failure : "Preview unavailable").font(.caption).multilineTextAlignment(.center)
          if size > 512 { Button("Retry preview") { retry += 1 } }
        }.padding(12).help(failure)
      } else { ProgressView().controlSize(.small).accessibilityLabel("Loading photograph") }
    }
    .task(id: "\(photo.id)-\(photo.locationRevision)-\(size)-\(retry)") {
      image = nil; failure = nil
      do {
        let rendered = try await previews.image(for: photo, maxPixel: size)
        try Task.checkCancellation()
        image = rendered
      } catch is CancellationError { }
      catch { failure = error.localizedDescription }
    }
    .onDisappear { image = nil }
  }
}
