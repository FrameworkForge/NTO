import Foundation

/// Every adjustable recipe field, addressable by name so presets, copy/paste and sync can carry a chosen subset.
public enum EditParameter: String, CaseIterable, Codable, Sendable, Hashable, CodingKeyRepresentable {
  case exposure, contrast, highlights, shadows, whites, blacks
  case temperature, tint, vibrance, saturation
  case sharpness, noiseReduction
  case crop, rotation

  public var group: EditGroup {
    switch self {
    case .exposure, .contrast, .highlights, .shadows, .whites, .blacks: .light
    case .temperature, .tint, .vibrance, .saturation: .colour
    case .sharpness, .noiseReduction: .detail
    case .crop, .rotation: .geometry
    }
  }
  public var title: String {
    switch self {
    case .noiseReduction: "Noise reduction"
    case .temperature: "Temperature (white balance)"
    case .tint: "Tint (white balance)"
    default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
  }
  /// Copied by default. White balance and geometry belong to one photograph and must be chosen deliberately.
  public static let safeDefaults: Set<EditParameter> = Set(allCases).subtracting([.temperature, .tint, .crop, .rotation])
  public static func parameters(in group: EditGroup) -> [EditParameter] { allCases.filter { $0.group == group } }
}

/// A single parameter's value in portable JSON form: a number, `null` for as-shot white balance, or a crop object.
public enum ParameterValue: Equatable, Sendable, Codable {
  case number(Double)
  case asShot
  case crop(EditRecipeCrop)
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() { self = .asShot }
    else if let number = try? container.decode(Double.self) { self = .number(number) }
    else { self = .crop(try container.decode(EditRecipeCrop.self)) }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .number(let value): try container.encode(value)
    case .asShot: try container.encodeNil()
    case .crop(let crop): try container.encode(crop)
    }
  }
}

public typealias RecipeAdjustments = [EditParameter: ParameterValue]

extension EditRecipe {
  public func value(of parameter: EditParameter) -> ParameterValue {
    switch parameter {
    case .exposure: .number(exposure)
    case .contrast: .number(contrast)
    case .highlights: .number(highlights)
    case .shadows: .number(shadows)
    case .whites: .number(whites)
    case .blacks: .number(blacks)
    case .temperature: temperature.map { .number($0) } ?? .asShot
    case .tint: .number(tint)
    case .vibrance: .number(vibrance)
    case .saturation: .number(saturation)
    case .sharpness: .number(sharpness)
    case .noiseReduction: .number(noiseReduction)
    case .crop: .crop(crop)
    case .rotation: .number(rotation)
    }
  }
  /// The chosen parameters' current values, ready to store in a preset or paste onto other photographs.
  public func adjustments(for parameters: Set<EditParameter>) -> RecipeAdjustments {
    Dictionary(uniqueKeysWithValues: parameters.map { ($0, value(of: $0)) })
  }
  /// Applies only the supplied parameters. Every other field keeps its value. Callers validate afterwards.
  public mutating func apply(_ adjustments: RecipeAdjustments) throws {
    for (parameter, value) in adjustments {
      switch (parameter, value) {
      case (.exposure, .number(let v)): exposure = v
      case (.contrast, .number(let v)): contrast = v
      case (.highlights, .number(let v)): highlights = v
      case (.shadows, .number(let v)): shadows = v
      case (.whites, .number(let v)): whites = v
      case (.blacks, .number(let v)): blacks = v
      case (.temperature, .number(let v)): temperature = v
      case (.temperature, .asShot): temperature = nil
      case (.tint, .number(let v)): tint = v
      case (.vibrance, .number(let v)): vibrance = v
      case (.saturation, .number(let v)): saturation = v
      case (.sharpness, .number(let v)): sharpness = v
      case (.noiseReduction, .number(let v)): noiseReduction = v
      case (.crop, .crop(let v)): crop = v
      case (.rotation, .number(let v)): rotation = v
      default: throw PresetError.invalidValue(parameter)
      }
    }
  }
}

/// Portable preset: a name plus the parameters it carries. Documented format version 1; unknown versions are refused.
public struct EditPreset: Codable, Identifiable, Equatable, Sendable {
  public static let currentFormatVersion = 1
  public var id: UUID
  public var name: String
  public var formatVersion: Int
  public var adjustments: RecipeAdjustments
  public init(id: UUID = UUID(), name: String, adjustments: RecipeAdjustments) {
    self.id = id; self.name = name; formatVersion = Self.currentFormatVersion; self.adjustments = adjustments
  }
  public var parameters: Set<EditParameter> { Set(adjustments.keys) }
  enum CodingKeys: String, CodingKey { case id, name, formatVersion, adjustments }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    formatVersion = try c.decode(Int.self, forKey: .formatVersion)
    guard formatVersion == Self.currentFormatVersion else { throw ContractError.unsupportedVersion(formatVersion) }
    id = try c.decode(UUID.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    adjustments = try c.decode(RecipeAdjustments.self, forKey: .adjustments)
  }
}

public enum PresetError: LocalizedError, Equatable {
  case emptyName, noParameters, missing, invalidValue(EditParameter)
  public var errorDescription: String? {
    switch self {
    case .emptyName: "Give this preset a name before saving."
    case .noParameters: "Choose at least one parameter to include."
    case .missing: "This preset is no longer in the library's Presets folder."
    case .invalidValue(let parameter): "The value for \(parameter.title) is not the right kind for that parameter."
    }
  }
}

/// Presets live as one JSON file each in the library's Presets folder, so they are user-owned, portable and shareable.
@MainActor @Observable public final class PresetStore {
  public private(set) var presets: [EditPreset] = []
  public private(set) var issues: [String] = []
  public let directory: URL
  public init(directory: URL) { self.directory = directory; reload() }

  public func reload() {
    presets = []; issues = []
    guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
    for url in urls where url.pathExtension.lowercased() == "json" {
      do { presets.append(try JSONDecoder().decode(EditPreset.self, from: Data(contentsOf: url))) }
      catch { issues.append("\(url.lastPathComponent): \(error.localizedDescription)") }
    }
    sort()
  }
  public func url(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

  @discardableResult public func save(_ preset: EditPreset) throws -> EditPreset {
    var saved = preset
    saved.name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !saved.name.isEmpty else { throw PresetError.emptyName }
    guard !saved.adjustments.isEmpty else { throw PresetError.noParameters }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(saved).write(to: url(for: saved.id), options: .atomic)
    presets.removeAll { $0.id == saved.id }; presets.append(saved); sort()
    return saved
  }
  public func rename(_ id: UUID, to name: String) throws {
    guard var preset = presets.first(where: { $0.id == id }) else { throw PresetError.missing }
    preset.name = name; try save(preset)
  }
  /// Removes the file only. Photographs that used the preset keep their recipes.
  public func delete(_ id: UUID) throws {
    guard presets.contains(where: { $0.id == id }) else { throw PresetError.missing }
    let file = url(for: id)
    if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    presets.removeAll { $0.id == id }
  }
  /// Imports a preset file; a colliding id gets a fresh one so an existing preset is never overwritten silently.
  @discardableResult public func importPreset(from source: URL) throws -> EditPreset {
    var preset = try JSONDecoder().decode(EditPreset.self, from: Data(contentsOf: source))
    if presets.contains(where: { $0.id == preset.id }) { preset.id = UUID() }
    return try save(preset)
  }
  public func export(_ id: UUID, to destination: URL) throws {
    guard presets.contains(where: { $0.id == id }) else { throw PresetError.missing }
    if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
    try FileManager.default.copyItem(at: url(for: id), to: destination)
  }
  private func sort() { presets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
}
