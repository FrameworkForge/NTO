import Foundation

/// Local URLs are renderer inputs only; they are never part of Cloud models.
public struct OriginalReference: Sendable {
  public let assetID: UUID
  public let url: URL
  public let bookmark: Data?
  public let fingerprint: String?
  public init(assetID: UUID, url: URL, bookmark: Data? = nil, fingerprint: String? = nil) {
    self.assetID = assetID
    self.url = url; self.bookmark = bookmark; self.fingerprint = fingerprint
  }
}
public struct RenderSpecification: Codable, Hashable, Sendable {
  public let maxDimension: Int
  public let format: String
  /// JPEG compression quality 0.1…1. Ignored by lossless formats.
  public let quality: Double
  public init(maxDimension: Int, format: String, quality: Double = 0.95) {
    self.maxDimension = maxDimension
    self.format = format
    self.quality = quality
  }
}
public struct RenderedResult: Sendable {
  public let data: Data
  public let width: Int
  public let height: Int
  public init(data: Data, width: Int, height: Int) {
    self.data = data
    self.width = width
    self.height = height
  }
}
public protocol PhotoRenderer: Sendable {
  func render(original: OriginalReference, recipe: EditRecipe, output: RenderSpecification)
    async throws -> RenderedResult
}
public enum RenderFailure: LocalizedError {
  case invalidRecipe, invalidOutput, assetMismatch, missingOriginal, changedOriginal, unsupportedRAW, decode, encode, tooLarge
  public var errorDescription: String? {
    switch self {
    case .invalidRecipe: "This edit recipe contains invalid or out-of-range values."
    case .invalidOutput: "Choose JPEG, PNG or TIFF, a maximum dimension between 1 and 30,000 pixels, and a JPEG quality between 0.1 and 1."
    case .assetMismatch: "This recipe belongs to a different photograph."
    case .missingOriginal: "The original is unavailable. Reconnect its drive or use Locate original in the inspector, then retry."
    case .changedOriginal: "The original's contents have changed. Locate the original matching this photograph before rendering."
    case .unsupportedRAW: "This RAW file cannot be developed by the system decoder. Check camera support and try a supported original."
    case .decode: "The original could not be decoded. Check that the file is complete and supported, then retry."
    case .encode: "The rendered image could not be produced. Try a smaller output and retry."
    case .tooLarge: "This renderer currently supports originals up to 120 megapixels."
    }
  }
}
public struct RenditionJob: Codable, Sendable {
  public let id: UUID
  public let assetId: UUID
  public let sourceObjectKey: String
  public let recipeRevision: Int
  public let target: Target
  public init(id: UUID, assetId: UUID, sourceObjectKey: String, recipeRevision: Int, target: Target)
  {
    self.id = id
    self.assetId = assetId
    self.sourceObjectKey = sourceObjectKey
    self.recipeRevision = recipeRevision
    self.target = target
  }
  public struct Target: Codable, Sendable {
    public let kind: RenditionKind
    public let maxDimension: Int
    public let format: String
    public init(kind: RenditionKind, maxDimension: Int, format: String) {
      self.kind = kind
      self.maxDimension = maxDimension
      self.format = format
    }
  }
}

public enum RenditionJobResult: Codable, Sendable {
  case completed(jobId: UUID, rendition: Rendition)
  case failed(jobId: UUID, error: CloudFailure)
  private enum CodingKeys: String, CodingKey { case jobId, status, rendition, error }
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(UUID.self, forKey: .jobId)
    switch try container.decode(String.self, forKey: .status) {
    case "completed":
      self = .completed(
        jobId: id, rendition: try container.decode(Rendition.self, forKey: .rendition))
    case "failed":
      self = .failed(jobId: id, error: try container.decode(CloudFailure.self, forKey: .error))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .status, in: container, debugDescription: "Unsupported rendition job status")
    }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .completed(let id, let rendition):
      try container.encode(id, forKey: .jobId)
      try container.encode("completed", forKey: .status)
      try container.encode(rendition, forKey: .rendition)
    case .failed(let id, let error):
      try container.encode(id, forKey: .jobId)
      try container.encode("failed", forKey: .status)
      try container.encode(error, forKey: .error)
    }
  }
}
