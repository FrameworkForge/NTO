import Foundation

extension EditRecipe {
  public static func neutral(assetID: UUID) -> EditRecipe {
    EditRecipe(schemaVersion: 1, assetId: assetID, revision: 1, exposure: 0, contrast: 0,
      saturation: 1, temperature: nil, tint: 0, sharpness: 0, noiseReduction: 0,
      crop: EditRecipeCrop(x: 0, y: 0, width: 1, height: 1), rotation: 0)
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
      [crop.x, crop.y, crop.width, crop.height].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      crop.width > 0, crop.height > 0, crop.x + crop.width <= 1, crop.y + crop.height <= 1,
      temperature.map({ $0.isFinite && (2000...50000).contains($0) }) ?? true
    else { throw RenderFailure.invalidRecipe }
  }
  public func hasSameAdjustments(as other: EditRecipe) -> Bool {
    var lhs = self, rhs = other; lhs.revision = 1; rhs.revision = 1
    return lhs == rhs
  }
}
