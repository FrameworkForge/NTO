import Foundation
import CoreImage
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Engine v1: full-resolution photographic operations precede output resizing for both preview and export.
/// The actor owns the CIContext and bounded encoded-result cache. No CI objects cross into SwiftUI.
public actor CoreImageRenderer: PhotoRenderer {
  private let outputSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  private let context = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    .workingFormat: CIFormat.RGBAh, .cacheIntermediates: false
  ])
  private var cache: [String: (RenderedResult, Int)] = [:]
  private var clock = 0
  private let cacheLimit: Int
  public private(set) var renderCount = 0
  public init(cacheLimit: Int = 64 * 1024 * 1024) { self.cacheLimit = max(0, cacheLimit) }
  public func render(original: OriginalReference, recipe: EditRecipe, output: RenderSpecification) async throws -> RenderedResult {
    try Task.checkCancellation(); try recipe.validate()
    guard original.assetID == recipe.assetId else { throw RenderFailure.assetMismatch }
    guard (1...30_000).contains(output.maxDimension), ["jpeg", "png", "tiff"].contains(output.format),
      output.quality.isFinite, (0.1...1).contains(output.quality) else { throw RenderFailure.invalidOutput }
    return try autoreleasepool {
      let url: URL
      if let bookmark = original.bookmark {
        var stale = false
        do { url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale) }
        catch { throw RenderFailure.missingOriginal }
      } else { url = original.url }
      let access = url.startAccessingSecurityScopedResource()
      defer { if access { url.stopAccessingSecurityScopedResource() } }
      guard url.isFileURL, FileManager.default.isReadableFile(atPath: url.path) else { throw RenderFailure.missingOriginal }
      let fingerprint = try PhotoImportWorker.fingerprint(url)
      if let expected = original.fingerprint, expected != fingerprint { throw RenderFailure.changedOriginal }
      let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
      var keyData = try encoder.encode(recipe); keyData.append(try encoder.encode(output))
      keyData.append(Data("nto-ci-v1|\(fingerprint)|\(ProcessInfo.processInfo.operatingSystemVersionString)".utf8))
      let key = SHA256.hash(data: keyData).map { String(format: "%02x", $0) }.joined()
      clock += 1
      if let cached = cache[key] { cache[key] = (cached.0, clock); return cached.0 }
      try Task.checkCancellation()
      let image = try pipeline(url: url, recipe: recipe)
      let scale = min(1, CGFloat(output.maxDimension) / max(image.extent.width, image.extent.height))
      let width = max(1, Int((image.extent.width * scale).rounded(.down)))
      let height = max(1, Int((image.extent.height * scale).rounded(.down)))
      let resized = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
      guard let rendered = context.createCGImage(resized, from: CGRect(x: 0, y: 0, width: width, height: height),
        format: .RGBA8, colorSpace: outputSpace) else { throw RenderFailure.encode }
      // GPU/decoder work may be noninterruptible; cancelled results never enter the cache or UI.
      try Task.checkCancellation()
      guard try PhotoImportWorker.fingerprint(url) == fingerprint else { throw RenderFailure.changedOriginal }
      let data = NSMutableData()
      let type = output.format == "jpeg" ? UTType.jpeg : output.format == "tiff" ? UTType.tiff : UTType.png
      guard let target = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { throw RenderFailure.encode }
      CGImageDestinationAddImage(target, rendered, [kCGImageDestinationLossyCompressionQuality: output.quality,
        kCGImagePropertyOrientation: 1] as CFDictionary)
      guard CGImageDestinationFinalize(target) else { throw RenderFailure.encode }
      try Task.checkCancellation()
      let result = RenderedResult(data: data as Data, width: width, height: height)
      renderCount += 1
      if data.length <= cacheLimit {
        cache[key] = (result, clock)
        while cachedBytes > cacheLimit, let oldest = cache.min(by: { $0.value.1 < $1.value.1 }) { cache.removeValue(forKey: oldest.key) }
      }
      return result
    }
  }
  public var cachedBytes: Int { cache.values.reduce(0) { $0 + $1.0.data.count } }

  private func pipeline(url: URL, recipe: EditRecipe) throws -> CIImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let typeID = CGImageSourceGetType(source), let type = UTType(typeID as String),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw RenderFailure.decode }
    guard width > 0, height > 0, Double(width) * Double(height) <= 120_000_000 else { throw RenderFailure.tooLarge }
    var image: CIImage
    // Decode → camera/RAW. Keep full decode scale identical for all output sizes.
    if type.conforms(to: .rawImage) {
      guard let raw = CIRAWFilter(imageURL: url) else { throw RenderFailure.unsupportedRAW }
      guard raw.nativeSize.width * raw.nativeSize.height <= 120_000_000 else { throw RenderFailure.tooLarge }
      raw.scaleFactor = 1; raw.isDraftModeEnabled = false; raw.exposure = 0
      raw.isLensCorrectionEnabled = false
      if let temperature = recipe.temperature { raw.neutralTemperature = Float(temperature) }
      raw.neutralTint = min(max(raw.neutralTint + Float(recipe.tint), -150), 150)
      guard let decoded = raw.outputImage else { throw RenderFailure.unsupportedRAW }
      image = decoded
    } else {
      guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw RenderFailure.decode }
      image = decoded
    }
    image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    let extent = image.extent
    guard !extent.isInfinite, !extent.isNull, extent.width > 0, extent.height > 0, extent.width * extent.height <= 120_000_000 else { throw RenderFailure.tooLarge }
    // Tone. Contrast is a signed offset from the neutral factor of 1.
    image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: recipe.exposure])
    image = image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1 + recipe.contrast, kCIInputSaturationKey: 1])
    // Tonal range: a five-point curve in sRGB-encoded tone with a pinned midtone (see RENDERING.md).
    if recipe.highlights != 0 || recipe.shadows != 0 || recipe.whites != 0 || recipe.blacks != 0 {
      let points = [
        CIVector(x: max(0, -0.15 * recipe.blacks), y: max(0, 0.15 * recipe.blacks)),
        CIVector(x: 0.25, y: 0.25 + 0.10 * recipe.shadows),
        CIVector(x: 0.5, y: 0.5),
        CIVector(x: 0.75, y: 0.75 + 0.10 * recipe.highlights),
        CIVector(x: 1 - max(0, 0.15 * recipe.whites), y: 1 - max(0, -0.15 * recipe.whites))
      ]
      image = image.applyingFilter("CIToneCurve", parameters: ["inputPoint0": points[0], "inputPoint1": points[1],
        "inputPoint2": points[2], "inputPoint3": points[3], "inputPoint4": points[4]])
    }
    // Colour. RAW uses camera white balance; raster intent is relative to D65.
    if !type.conforms(to: .rawImage), recipe.temperature != nil || recipe.tint != 0 {
      image = image.applyingFilter("CITemperatureAndTint", parameters: [
        "inputNeutral": CIVector(x: recipe.temperature ?? 6500, y: recipe.tint),
        "inputTargetNeutral": CIVector(x: 6500, y: 0)
      ])
    }
    if recipe.vibrance != 0 {
      image = image.applyingFilter("CIVibrance", parameters: ["inputAmount": recipe.vibrance])
    }
    image = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: recipe.saturation, kCIInputContrastKey: 1])
    // Detail is computed at original resolution, never at preview-dependent radii.
    if recipe.noiseReduction > 0 {
      image = image.clampedToExtent().applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": recipe.noiseReduction * 0.1, "inputSharpness": 0]).cropped(to: extent)
    }
    if recipe.sharpness > 0 {
      image = image.clampedToExtent().applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: recipe.sharpness]).cropped(to: extent)
    }
    // Geometry: normalized top-left crop on the oriented original, then clockwise rotation.
    let crop = recipe.crop
    let rect = CGRect(x: crop.x * extent.width, y: (1 - crop.y - crop.height) * extent.height,
      width: crop.width * extent.width, height: crop.height * extent.height).integral.intersection(extent)
    guard rect.width >= 1, rect.height >= 1 else { throw RenderFailure.invalidRecipe }
    image = image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    if recipe.rotation != 0 {
      image = image.transformed(by: CGAffineTransform(rotationAngle: -recipe.rotation * .pi / 180))
      let bounds = image.extent.integral
      image = image.transformed(by: CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
    }
    // Effects: identity in recipe v1. Output: opaque SDR sRGB, black outside rotated image bounds.
    return image.composited(over: CIImage(color: .black).cropped(to: image.extent)).cropped(to: image.extent)
  }
}
