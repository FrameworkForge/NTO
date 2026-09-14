import Foundation
import CoreGraphics

public enum CropAspect: String, CaseIterable, Identifiable, Sendable {
  case free, original, square, threeTwo, fourThree, sixteenNine, fiveFour
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .free: "Free"
    case .original: "Original"
    case .square: "1:1"
    case .threeTwo: "3:2"
    case .fourThree: "4:3"
    case .sixteenNine: "16:9"
    case .fiveFour: "5:4"
    }
  }
  /// Width divided by height in pixels for a landscape orientation; nil for free.
  public func ratio(imageSize: CGSize) -> Double? {
    switch self {
    case .free: nil
    case .original: imageSize.height > 0 ? max(imageSize.width, imageSize.height) / min(imageSize.width, imageSize.height) : nil
    case .square: 1
    case .threeTwo: 3.0 / 2.0
    case .fourThree: 4.0 / 3.0
    case .sixteenNine: 16.0 / 9.0
    case .fiveFour: 5.0 / 4.0
    }
  }
}

/// An in-progress crop. `pending` is view state until Return commits it as one undo step; Escape restores `initial`.
public struct CropSession: Equatable, Sendable {
  public var initial: EditRecipeCrop
  public var pending: EditRecipeCrop
  public var aspect: CropAspect = .free
  public var portrait = false
  public init(initial: EditRecipeCrop) { self.initial = initial; pending = initial }
}

public enum CropHandle: Equatable, Sendable {
  case none, move, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

/// Pure crop arithmetic in normalized image coordinates (origin top-left, y down). Views convert to and from points.
public enum CropGeometry {
  public static let minimumSize = 0.02

  /// The rectangle a `scaledToFit` image occupies inside a container.
  public static func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else { return .zero }
    let scale = min(container.width / imageSize.width, container.height / imageSize.height)
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
  }
  public static func viewRect(_ crop: EditRecipeCrop, in displayed: CGRect) -> CGRect {
    CGRect(x: displayed.minX + crop.x * displayed.width, y: displayed.minY + crop.y * displayed.height,
      width: crop.width * displayed.width, height: crop.height * displayed.height)
  }
  /// Normalized height-per-width factor for an aspect, so `height = width * k` keeps the pixel ratio.
  public static func heightFactor(aspect: CropAspect, portrait: Bool, imageSize: CGSize) -> Double? {
    guard var ratio = aspect.ratio(imageSize: imageSize), imageSize.height > 0 else { return nil }
    if portrait { ratio = 1 / ratio }
    return (imageSize.width / imageSize.height) / ratio
  }
  public static func handle(at point: CGPoint, rect: CGRect, tolerance: CGFloat) -> CropHandle {
    let nearLeft = abs(point.x - rect.minX) <= tolerance, nearRight = abs(point.x - rect.maxX) <= tolerance
    let nearTop = abs(point.y - rect.minY) <= tolerance, nearBottom = abs(point.y - rect.maxY) <= tolerance
    let insideX = point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance
    let insideY = point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
    guard insideX, insideY else { return .none }
    switch (nearLeft, nearRight, nearTop, nearBottom) {
    case (true, _, true, _): return .topLeft
    case (_, true, true, _): return .topRight
    case (true, _, _, true): return .bottomLeft
    case (_, true, _, true): return .bottomRight
    case (true, _, _, _): return .left
    case (_, true, _, _): return .right
    case (_, _, true, _): return .top
    case (_, _, _, true): return .bottom
    default: return rect.insetBy(dx: tolerance, dy: tolerance).contains(point) || rect.contains(point) ? .move : .none
    }
  }

  /// Applies a normalized drag delta to `start`. With `heightFactor`, height follows width around the anchored side.
  public static func resize(_ start: EditRecipeCrop, handle: CropHandle, dx: Double, dy: Double, heightFactor k: Double?) -> EditRecipeCrop {
    guard dx.isFinite, dy.isFinite else { return start }
    var l = start.x, t = start.y, r = start.x + start.width, b = start.y + start.height
    switch handle {
    case .none: return start
    case .move:
      var nl = l + dx, nt = t + dy
      nl = min(max(nl, 0), 1 - start.width); nt = min(max(nt, 0), 1 - start.height)
      return EditRecipeCrop(x: nl, y: nt, width: start.width, height: start.height)
    case .left, .topLeft, .bottomLeft: l = min(max(l + dx, 0), r - minimumSize)
    case .right, .topRight, .bottomRight: r = max(min(r + dx, 1), l + minimumSize)
    default: break
    }
    switch handle {
    case .top, .topLeft, .topRight: t = min(max(t + dy, 0), b - minimumSize)
    case .bottom, .bottomLeft, .bottomRight: b = max(min(b + dy, 1), t + minimumSize)
    default: break
    }
    if let k, k > 0 {
      let anchorLeft = [CropHandle.right, .topRight, .bottomRight].contains(handle)
      let anchorTop = [CropHandle.bottom, .bottomLeft, .bottomRight].contains(handle)
      let horizontalEdge = handle == .left || handle == .right, verticalEdge = handle == .top || handle == .bottom
      var w = r - l, h = b - t
      if verticalEdge { w = h / k } else { h = w * k }
      if horizontalEdge {
        let cy = (t + b) / 2
        h = min(h, 2 * min(cy, 1 - cy)); w = h / k
        t = cy - h / 2; b = cy + h / 2
        if anchorLeft { r = l + w } else { l = r - w }
      } else if verticalEdge {
        let cx = (l + r) / 2
        w = min(w, 2 * min(cx, 1 - cx)); h = w * k
        l = cx - w / 2; r = cx + w / 2
        if anchorTop { b = t + h } else { t = b - h }
      } else {
        let maxW = anchorLeft ? 1 - l : r, maxH = anchorTop ? 1 - t : b
        if h > maxH { h = maxH; w = h / k }
        if w > maxW { w = maxW; h = w * k }
        if anchorLeft { r = l + w } else { l = r - w }
        if anchorTop { b = t + h } else { t = b - h }
      }
    }
    return EditRecipe.clampedCrop(EditRecipeCrop(x: l, y: t, width: r - l, height: b - t), minimumSize: minimumSize)
  }

  /// The largest rectangle of the aspect that fits inside `within`, centred on it.
  public static func fitted(aspect k: Double?, within crop: EditRecipeCrop) -> EditRecipeCrop {
    guard let k, k > 0 else { return crop }
    var w = crop.width, h = w * k
    if h > crop.height { h = crop.height; w = h / k }
    return EditRecipe.clampedCrop(EditRecipeCrop(x: crop.x + (crop.width - w) / 2, y: crop.y + (crop.height - h) / 2, width: w, height: h), minimumSize: minimumSize)
  }

  /// Maps a point on the displayed (cropped, then rotated) render back to normalized coordinates on the oriented original.
  public static func originalPoint(fromDisplayed p: CGPoint, crop: EditRecipeCrop, rotation: Double, imageSize: CGSize) -> CGPoint {
    let cw = crop.width * imageSize.width, ch = crop.height * imageSize.height
    guard cw > 0, ch > 0, imageSize.width > 0, imageSize.height > 0 else { return p }
    let theta = rotation * .pi / 180
    let bw = abs(cw * cos(theta)) + abs(ch * sin(theta)), bh = abs(cw * sin(theta)) + abs(ch * cos(theta))
    // Displayed point relative to the bounding-box centre, in pixels with y down.
    let dx = (p.x - 0.5) * bw, dy = (p.y - 0.5) * bh
    // The render rotated the crop clockwise by theta; undo it (counter-clockwise in y-down coordinates).
    let ux = dx * cos(theta) + dy * sin(theta), uy = -dx * sin(theta) + dy * cos(theta)
    let ox = (crop.x + crop.width / 2) * imageSize.width + ux, oy = (crop.y + crop.height / 2) * imageSize.height + uy
    return CGPoint(x: min(max(ox / imageSize.width, 0), 1), y: min(max(oy / imageSize.height, 0), 1))
  }
}
