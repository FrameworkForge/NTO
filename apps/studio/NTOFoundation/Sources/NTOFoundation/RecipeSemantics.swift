import Foundation

/// Inspector groups for recipe v1 fields. Groups organise controls; they do not change field semantics.
public enum EditGroup: String, CaseIterable, Identifiable, Sendable {
  case light = "Light"
  case colour = "Colour"
  case detail = "Detail"
  case geometry = "Geometry"
  public var id: String { rawValue }
}

extension EditRecipe {
  public static func neutral(assetID: UUID) -> EditRecipe {
    EditRecipe(schemaVersion: 1, assetId: assetID, revision: 1, exposure: 0, contrast: 0,
      saturation: 1, temperature: nil, tint: 0, sharpness: 0, noiseReduction: 0,
      crop: EditRecipeCrop(x: 0, y: 0, width: 1, height: 1), rotation: 0,
      highlights: 0, shadows: 0, whites: 0, blacks: 0, vibrance: 0)
  }
  public func validate() throws {
    guard schemaVersion == 1 else { throw ContractError.unsupportedVersion(schemaVersion) }
    guard revision > 0, revision <= 9_007_199_254_740_991,
      exposure.isFinite, (-5...5).contains(exposure),
      contrast.isFinite, (-1...1).contains(contrast),
      saturation.isFinite, (0...2).contains(saturation),
      tint.isFinite, (-150...150).contains(tint),
      sharpness.isFinite, (0...2).contains(sharpness),
      noiseReduction.isFinite, (0...1).contains(noiseReduction),
      rotation.isFinite, (-180...180).contains(rotation),
      [highlights, shadows, whites, blacks, vibrance].allSatisfy({ $0.isFinite && (-1...1).contains($0) }),
      [crop.x, crop.y, crop.width, crop.height].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      crop.width > 0, crop.height > 0, crop.x + crop.width <= 1, crop.y + crop.height <= 1,
      temperature.map({ $0.isFinite && (2000...50000).contains($0) }) ?? true
    else { throw RenderFailure.invalidRecipe }
  }
  public func hasSameAdjustments(as other: EditRecipe) -> Bool {
    var lhs = self, rhs = other; lhs.revision = 1; rhs.revision = 1
    return lhs == rhs
  }

  /// Restores one group's fields to neutral while leaving every other field unchanged.
  public mutating func reset(_ group: EditGroup) {
    let neutral = EditRecipe.neutral(assetID: assetId)
    switch group {
    case .light:
      exposure = neutral.exposure; contrast = neutral.contrast
      highlights = neutral.highlights; shadows = neutral.shadows; whites = neutral.whites; blacks = neutral.blacks
    case .colour:
      temperature = neutral.temperature; tint = neutral.tint; vibrance = neutral.vibrance; saturation = neutral.saturation
    case .detail: sharpness = neutral.sharpness; noiseReduction = neutral.noiseReduction
    case .geometry: crop = neutral.crop; rotation = neutral.rotation
    }
  }
  public func isNeutral(_ group: EditGroup) -> Bool {
    var copy = self; copy.reset(group)
    return copy.hasSameAdjustments(as: self)
  }

  /// Wraps any finite angle into the recipe's (-180, 180] degree range, so repeated quarter turns stay valid.
  public static func normalizedRotation(_ degrees: Double) -> Double {
    guard degrees.isFinite else { return 0 }
    var value = degrees.truncatingRemainder(dividingBy: 360)
    if value <= -180 { value += 360 }
    if value > 180 { value -= 360 }
    return value == 0 ? 0 : value
  }

  /// Clamps a proposed crop into a valid normalized rectangle: positive size, wholly inside the oriented original.
  public static func clampedCrop(_ crop: EditRecipeCrop, minimumSize: Double = 0.01) -> EditRecipeCrop {
    guard [crop.x, crop.y, crop.width, crop.height].allSatisfy(\.isFinite) else {
      return EditRecipeCrop(x: 0, y: 0, width: 1, height: 1)
    }
    let width = min(max(crop.width, minimumSize), 1), height = min(max(crop.height, minimumSize), 1)
    let x = min(max(crop.x, 0), 1 - width), y = min(max(crop.y, 0), 1 - height)
    return EditRecipeCrop(x: x, y: y, width: width, height: height)
  }
}
