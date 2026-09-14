import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct LinearRGB: Sendable, Equatable {
  public var r: Double, g: Double, b: Double
  public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
  /// Chroma relative to green: 0 for a neutral.
  public var chroma: Double { max(abs(r - g), abs(b - g)) / max(g, 1e-4) }
}

/// The white-balance eyedropper. For raster images it solves temperature and tint against the same Core Image
/// stage the renderer uses, so applying the result makes the sampled colour neutral. For RAW it asks the decoder.
public enum WhiteBalanceSampler {
  public static let temperatureRange = 2000.0...50000.0
  public static let tintRange = -150.0...150.0

  /// Average linear colour of a small square around a normalized point on an oriented sRGB image.
  public static func averageLinearColour(in image: CGImage, at normalized: CGPoint, radius: Int = 2) throws -> LinearRGB {
    let side = radius * 2 + 1
    let cx = Int((normalized.x * Double(image.width)).rounded(.down)), cy = Int((normalized.y * Double(image.height)).rounded(.down))
    let origin = CGPoint(x: min(max(cx - radius, 0), max(image.width - side, 0)), y: min(max(cy - radius, 0), max(image.height - side, 0)))
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      // Draw the image so the sampled square lands at the context origin (Core Graphics y is up).
      let flippedY = Double(image.height) - origin.y - Double(side)
      context.draw(image, in: CGRect(x: -origin.x, y: -flippedY, width: Double(image.width), height: Double(image.height)))
      return true
    }
    guard drew else { throw RenderFailure.decode }
    var sum = (0.0, 0.0, 0.0)
    for index in stride(from: 0, to: bytes.count, by: 4) {
      sum.0 += linear(bytes[index]); sum.1 += linear(bytes[index + 1]); sum.2 += linear(bytes[index + 2])
    }
    let n = Double(side * side)
    return LinearRGB(r: sum.0 / n, g: sum.1 / n, b: sum.2 / n)
  }
  static func linear(_ byte: UInt8) -> Double {
    let c = Double(byte) / 255
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
  }

  /// Finds the (temperature, tint) whose raster white-balance correction makes `colour` neutral.
  public static func neutral(forLinear colour: LinearRGB) -> (temperature: Double, tint: Double) {
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .outputColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf, .cacheIntermediates: false, .useSoftwareRenderer: true
    ])
    func score(_ temperature: Double, _ tint: Double) -> Double { corrected(colour, temperature: temperature, tint: tint, context: context).chroma }
    var best = (temperature: 6500.0, tint: 0.0, score: score(6500, 0))
    let temperatures = (0..<24).map { exp(log(2000.0) + (log(50000.0) - log(2000.0)) * Double($0) / 23) }
    for temperature in temperatures {
      for tint in stride(from: -150.0, through: 150.0, by: 25) {
        let value = score(temperature, tint)
        if value < best.score { best = (temperature, tint, value) }
      }
    }
    var temperatureStep = 1.15, tintStep = 12.0
    for _ in 0..<7 {
      var improved = true
      while improved {
        improved = false
        for candidate in [(best.temperature * temperatureStep, best.tint), (best.temperature / temperatureStep, best.tint),
          (best.temperature, best.tint + tintStep), (best.temperature, best.tint - tintStep)] {
          let temperature = min(max(candidate.0, temperatureRange.lowerBound), temperatureRange.upperBound)
          let tint = min(max(candidate.1, tintRange.lowerBound), tintRange.upperBound)
          let value = score(temperature, tint)
          if value < best.score - 1e-6 { best = (temperature, tint, value); improved = true }
        }
      }
      temperatureStep = 1 + (temperatureStep - 1) / 2; tintStep /= 2
    }
    return (best.temperature.rounded(), best.tint.rounded())
  }

  /// The renderer's raster white-balance stage applied to one colour.
  public static func corrected(_ colour: LinearRGB, temperature: Double, tint: Double, context: CIContext) -> LinearRGB {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let source = CIImage(color: CIColor(red: colour.r, green: colour.g, blue: colour.b, colorSpace: space) ?? CIColor(red: colour.r, green: colour.g, blue: colour.b))
      .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let filtered = source.applyingFilter("CITemperatureAndTint", parameters: [
      "inputNeutral": CIVector(x: temperature, y: tint), "inputTargetNeutral": CIVector(x: 6500, y: 0)
    ])
    var pixel = [Float](repeating: 0, count: 4)
    pixel.withUnsafeMutableBytes { buffer in
      context.render(filtered, toBitmap: buffer.baseAddress!, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: space)
    }
    return LinearRGB(r: Double(pixel[0]), g: Double(pixel[1]), b: Double(pixel[2]))
  }

  /// Asks the RAW decoder for the white balance that makes the location neutral. Needs qualification on real camera files.
  public static func rawNeutral(original: OriginalReference, at normalized: CGPoint) throws -> (temperature: Double, tint: Double) {
    var url = original.url
    if let bookmark = original.bookmark {
      var stale = false
      if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale) { url = resolved }
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    guard let raw = CIRAWFilter(imageURL: url) else { throw RenderFailure.unsupportedRAW }
    raw.isDraftModeEnabled = true; raw.scaleFactor = 0.25
    guard let extent = raw.outputImage?.extent, extent.width > 0 else { throw RenderFailure.unsupportedRAW }
    raw.neutralLocation = CGPoint(x: extent.minX + normalized.x * extent.width, y: extent.minY + (1 - normalized.y) * extent.height)
    let temperature = min(max(Double(raw.neutralTemperature), temperatureRange.lowerBound), temperatureRange.upperBound)
    let tint = min(max(Double(raw.neutralTint), tintRange.lowerBound), tintRange.upperBound)
    return (temperature.rounded(), tint.rounded())
  }
}
