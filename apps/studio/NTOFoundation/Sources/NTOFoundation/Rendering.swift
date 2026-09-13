import Foundation

/// Local URLs are renderer inputs only; they are never part of Cloud models.
public struct OriginalReference: Sendable {
  public let assetID: UUID
  public let url: URL
  public init(assetID: UUID, url: URL) {
    self.assetID = assetID
    self.url = url
  }
}
public struct RenderSpecification: Sendable {
  public let maxDimension: Int
  public let format: String
  public init(maxDimension: Int, format: String) {
    self.maxDimension = maxDimension
    self.format = format
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
  case notImplemented
  public var errorDescription: String? {
    "Image rendering is not available in this foundation build."
  }
}
public struct UnavailableRenderer: PhotoRenderer {
  public init() {}
  public func render(original: OriginalReference, recipe: EditRecipe, output: RenderSpecification)
    async throws -> RenderedResult
  { throw RenderFailure.notImplemented }
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
