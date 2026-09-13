// Generated from packages/shared-types/schema.json.
import Foundation

public enum ContractError: Error { case unsupportedVersion(Int) }

public enum AssetFlag: String, Codable, Sendable { case `none`; case `pick`; case `reject` }

public struct EditRecipeCrop: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    enum CodingKeys: String, CodingKey { case x, y, width, height }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
    }
}

public enum RenditionKind: String, Codable, Sendable { case `thumbnail`; case `preview`; case `web`; case `master`; case `export` }

public enum PublicationDestination: String, Codable, Sendable { case `gallery`; case `portfolio` }

public enum PublicationStatus: String, Codable, Sendable { case `draft`; case `published` }

public enum PublicationVisibility: String, Codable, Sendable { case `public`; case `unlisted`; case `password` }

public enum PublicationDownloads: String, Codable, Sendable { case `none`; case `web`; case `master` }

public struct Project: Codable, Equatable, Sendable {
    public var id: UUID
    public var ownerId: UUID
    public var title: String
    public var createdAt: String
    public init(id: UUID, ownerId: UUID, title: String, createdAt: String) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.createdAt = createdAt
    }
    enum CodingKeys: String, CodingKey { case id, ownerId, title, createdAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerId = try c.decode(UUID.self, forKey: .ownerId)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerId, forKey: .ownerId)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

public struct Asset: Codable, Equatable, Sendable {
    public var id: UUID
    public var ownerId: UUID
    public var filename: String
    public var mediaType: String
    public var originalObjectKey: String?
    public var width: Int
    public var height: Int
    public var rating: Int
    public var flag: AssetFlag
    public var favourite: Bool
    public init(id: UUID, ownerId: UUID, filename: String, mediaType: String, originalObjectKey: String?, width: Int, height: Int, rating: Int, flag: AssetFlag, favourite: Bool) {
        self.id = id
        self.ownerId = ownerId
        self.filename = filename
        self.mediaType = mediaType
        self.originalObjectKey = originalObjectKey
        self.width = width
        self.height = height
        self.rating = rating
        self.flag = flag
        self.favourite = favourite
    }
    enum CodingKeys: String, CodingKey { case id, ownerId, filename, mediaType, originalObjectKey, width, height, rating, flag, favourite }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerId = try c.decode(UUID.self, forKey: .ownerId)
        filename = try c.decode(String.self, forKey: .filename)
        mediaType = try c.decode(String.self, forKey: .mediaType)
        originalObjectKey = try c.decode(Optional<String>.self, forKey: .originalObjectKey)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        rating = try c.decode(Int.self, forKey: .rating)
        flag = try c.decode(AssetFlag.self, forKey: .flag)
        favourite = try c.decode(Bool.self, forKey: .favourite)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerId, forKey: .ownerId)
        try c.encode(filename, forKey: .filename)
        try c.encode(mediaType, forKey: .mediaType)
        try c.encode(originalObjectKey, forKey: .originalObjectKey)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(rating, forKey: .rating)
        try c.encode(flag, forKey: .flag)
        try c.encode(favourite, forKey: .favourite)
    }
}

public struct Collection: Codable, Equatable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var title: String
    public var assetIds: [UUID]
    public init(id: UUID, projectId: UUID, title: String, assetIds: [UUID]) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.assetIds = assetIds
    }
    enum CodingKeys: String, CodingKey { case id, projectId, title, assetIds }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        projectId = try c.decode(UUID.self, forKey: .projectId)
        title = try c.decode(String.self, forKey: .title)
        assetIds = try c.decode([UUID].self, forKey: .assetIds)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(projectId, forKey: .projectId)
        try c.encode(title, forKey: .title)
        try c.encode(assetIds, forKey: .assetIds)
    }
}

public struct EditRecipe: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var assetId: UUID
    public var revision: Int
    public var exposure: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double?
    public var tint: Double
    public var sharpness: Double
    public var noiseReduction: Double
    public var crop: EditRecipeCrop
    public var rotation: Double
    public init(schemaVersion: Int, assetId: UUID, revision: Int, exposure: Double, contrast: Double, saturation: Double, temperature: Double?, tint: Double, sharpness: Double, noiseReduction: Double, crop: EditRecipeCrop, rotation: Double) {
        self.schemaVersion = schemaVersion
        self.assetId = assetId
        self.revision = revision
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
        self.sharpness = sharpness
        self.noiseReduction = noiseReduction
        self.crop = crop
        self.rotation = rotation
    }
    enum CodingKeys: String, CodingKey { case schemaVersion, assetId, revision, exposure, contrast, saturation, temperature, tint, sharpness, noiseReduction, crop, rotation }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw ContractError.unsupportedVersion(schemaVersion) }
        assetId = try c.decode(UUID.self, forKey: .assetId)
        revision = try c.decode(Int.self, forKey: .revision)
        exposure = try c.decode(Double.self, forKey: .exposure)
        contrast = try c.decode(Double.self, forKey: .contrast)
        saturation = try c.decode(Double.self, forKey: .saturation)
        temperature = try c.decode(Optional<Double>.self, forKey: .temperature)
        tint = try c.decode(Double.self, forKey: .tint)
        sharpness = try c.decode(Double.self, forKey: .sharpness)
        noiseReduction = try c.decode(Double.self, forKey: .noiseReduction)
        crop = try c.decode(EditRecipeCrop.self, forKey: .crop)
        rotation = try c.decode(Double.self, forKey: .rotation)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(assetId, forKey: .assetId)
        try c.encode(revision, forKey: .revision)
        try c.encode(exposure, forKey: .exposure)
        try c.encode(contrast, forKey: .contrast)
        try c.encode(saturation, forKey: .saturation)
        try c.encode(temperature, forKey: .temperature)
        try c.encode(tint, forKey: .tint)
        try c.encode(sharpness, forKey: .sharpness)
        try c.encode(noiseReduction, forKey: .noiseReduction)
        try c.encode(crop, forKey: .crop)
        try c.encode(rotation, forKey: .rotation)
    }
}

public struct Rendition: Codable, Equatable, Sendable {
    public var id: UUID
    public var assetId: UUID
    public var recipeRevision: Int
    public var kind: RenditionKind
    public var objectKey: String
    public var width: Int
    public var height: Int
    public var contentKey: String
    public init(id: UUID, assetId: UUID, recipeRevision: Int, kind: RenditionKind, objectKey: String, width: Int, height: Int, contentKey: String) {
        self.id = id
        self.assetId = assetId
        self.recipeRevision = recipeRevision
        self.kind = kind
        self.objectKey = objectKey
        self.width = width
        self.height = height
        self.contentKey = contentKey
    }
    enum CodingKeys: String, CodingKey { case id, assetId, recipeRevision, kind, objectKey, width, height, contentKey }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        assetId = try c.decode(UUID.self, forKey: .assetId)
        recipeRevision = try c.decode(Int.self, forKey: .recipeRevision)
        kind = try c.decode(RenditionKind.self, forKey: .kind)
        objectKey = try c.decode(String.self, forKey: .objectKey)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        contentKey = try c.decode(String.self, forKey: .contentKey)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(assetId, forKey: .assetId)
        try c.encode(recipeRevision, forKey: .recipeRevision)
        try c.encode(kind, forKey: .kind)
        try c.encode(objectKey, forKey: .objectKey)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(contentKey, forKey: .contentKey)
    }
}

public struct Publication: Codable, Equatable, Sendable {
    public var id: UUID
    public var ownerId: UUID
    public var projectId: UUID
    public var destination: PublicationDestination
    public var title: String
    public var slug: String
    public var status: PublicationStatus
    public var visibility: PublicationVisibility
    public var downloads: PublicationDownloads
    public var assetIds: [UUID]
    public var coverAssetId: UUID?
    public var revision: Int
    public init(id: UUID, ownerId: UUID, projectId: UUID, destination: PublicationDestination, title: String, slug: String, status: PublicationStatus, visibility: PublicationVisibility, downloads: PublicationDownloads, assetIds: [UUID], coverAssetId: UUID?, revision: Int) {
        self.id = id
        self.ownerId = ownerId
        self.projectId = projectId
        self.destination = destination
        self.title = title
        self.slug = slug
        self.status = status
        self.visibility = visibility
        self.downloads = downloads
        self.assetIds = assetIds
        self.coverAssetId = coverAssetId
        self.revision = revision
    }
    enum CodingKeys: String, CodingKey { case id, ownerId, projectId, destination, title, slug, status, visibility, downloads, assetIds, coverAssetId, revision }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerId = try c.decode(UUID.self, forKey: .ownerId)
        projectId = try c.decode(UUID.self, forKey: .projectId)
        destination = try c.decode(PublicationDestination.self, forKey: .destination)
        title = try c.decode(String.self, forKey: .title)
        slug = try c.decode(String.self, forKey: .slug)
        status = try c.decode(PublicationStatus.self, forKey: .status)
        visibility = try c.decode(PublicationVisibility.self, forKey: .visibility)
        downloads = try c.decode(PublicationDownloads.self, forKey: .downloads)
        assetIds = try c.decode([UUID].self, forKey: .assetIds)
        coverAssetId = try c.decode(Optional<UUID>.self, forKey: .coverAssetId)
        revision = try c.decode(Int.self, forKey: .revision)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerId, forKey: .ownerId)
        try c.encode(projectId, forKey: .projectId)
        try c.encode(destination, forKey: .destination)
        try c.encode(title, forKey: .title)
        try c.encode(slug, forKey: .slug)
        try c.encode(status, forKey: .status)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(downloads, forKey: .downloads)
        try c.encode(assetIds, forKey: .assetIds)
        try c.encode(coverAssetId, forKey: .coverAssetId)
        try c.encode(revision, forKey: .revision)
    }
}

public struct EcosystemFixture: Codable, Equatable, Sendable {
    public var contractVersion: Int
    public var projects: [Project]
    public var assets: [Asset]
    public var collections: [Collection]
    public var recipes: [EditRecipe]
    public var renditions: [Rendition]
    public var publications: [Publication]
    public init(contractVersion: Int, projects: [Project], assets: [Asset], collections: [Collection], recipes: [EditRecipe], renditions: [Rendition], publications: [Publication]) {
        self.contractVersion = contractVersion
        self.projects = projects
        self.assets = assets
        self.collections = collections
        self.recipes = recipes
        self.renditions = renditions
        self.publications = publications
    }
    enum CodingKeys: String, CodingKey { case contractVersion, projects, assets, collections, recipes, renditions, publications }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contractVersion = try c.decode(Int.self, forKey: .contractVersion)
        guard contractVersion == 1 else { throw ContractError.unsupportedVersion(contractVersion) }
        projects = try c.decode([Project].self, forKey: .projects)
        assets = try c.decode([Asset].self, forKey: .assets)
        collections = try c.decode([Collection].self, forKey: .collections)
        recipes = try c.decode([EditRecipe].self, forKey: .recipes)
        renditions = try c.decode([Rendition].self, forKey: .renditions)
        publications = try c.decode([Publication].self, forKey: .publications)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(contractVersion, forKey: .contractVersion)
        try c.encode(projects, forKey: .projects)
        try c.encode(assets, forKey: .assets)
        try c.encode(collections, forKey: .collections)
        try c.encode(recipes, forKey: .recipes)
        try c.encode(renditions, forKey: .renditions)
        try c.encode(publications, forKey: .publications)
    }
}
