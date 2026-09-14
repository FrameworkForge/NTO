import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportFormat: String, Codable, CaseIterable, Sendable, Identifiable {
  case jpeg, tiff
  public var id: String { rawValue }
  public var title: String { self == .jpeg ? "JPEG" : "TIFF" }
  public var fileExtension: String { self == .jpeg ? "jpg" : "tif" }
  public var utType: UTType { self == .jpeg ? .jpeg : .tiff }
}

/// Original size renders at the source resolution; fit resizes so the longest edge is at most `maxDimension`, never upscaling.
public enum ExportSizing: Codable, Equatable, Sendable {
  case original
  case fit(maxDimension: Int)
  public var maxDimension: Int {
    switch self {
    case .original: 30_000
    case .fit(let value): min(max(value, 1), 30_000)
    }
  }
}

public enum ExportMetadataPolicy: String, Codable, CaseIterable, Sendable, Identifiable {
  /// No metadata beyond the image itself.
  case none
  /// Caption and keywords from Studio as XMP Dublin Core; no camera data.
  case descriptive
  /// Camera capture metadata from the original plus caption and keywords. Location only when explicitly included.
  case camera
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .none: "None"
    case .descriptive: "Caption and keywords"
    case .camera: "Camera data, caption and keywords"
    }
  }
}

public enum ExportConflictPolicy: String, Codable, CaseIterable, Sendable, Identifiable {
  case skip, keepBoth, replace
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .skip: "Skip"
    case .keepBoth: "Keep both (add a number)"
    case .replace: "Replace"
    }
  }
}

public struct ExportSpecification: Codable, Equatable, Sendable {
  public var format: ExportFormat = .jpeg
  public var quality: Double = 0.92
  public var sizing: ExportSizing = .original
  public var filenameTemplate: String = "{name}"
  public var metadata: ExportMetadataPolicy = .descriptive
  public var includeLocation = false
  public var conflicts: ExportConflictPolicy = .skip
  public init() {}
  public var renderSpecification: RenderSpecification {
    RenderSpecification(maxDimension: sizing.maxDimension, format: format.rawValue, quality: min(max(quality, 0.1), 1))
  }
}

public enum ExportError: LocalizedError, Equatable {
  case destinationUnavailable, write(String), exists
  public var errorDescription: String? {
    switch self {
    case .destinationUnavailable: "The export folder is not available. Choose a folder on a connected drive and retry."
    case .write(let detail): "The file could not be written: \(detail)"
    case .exists: "A file with this name already exists. Skipped; choose Keep both or Replace to export it."
    }
  }
}

/// Filename templates and conflict resolution. Tokens: {name}, {index}, {project}, {date}, {rating}.
public enum ExportNaming {
  public static let tokens = ["{name}", "{index}", "{project}", "{date}", "{rating}"]
  public static func filename(template: String, photo: PhotoRecord, projectTitle: String, index: Int, count: Int, format: ExportFormat) -> String {
    let base = (photo.filename as NSString).deletingPathExtension
    let width = max(String(max(count, 1)).count, 1)
    let padded = String(repeating: "0", count: max(0, width - String(index).count)) + String(index)
    var name = template.trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty { name = "{name}" }
    name = name.replacingOccurrences(of: "{name}", with: base)
      .replacingOccurrences(of: "{index}", with: padded)
      .replacingOccurrences(of: "{project}", with: projectTitle)
      .replacingOccurrences(of: "{date}", with: date(for: photo))
      .replacingOccurrences(of: "{rating}", with: String(photo.rating))
    name = sanitized(name)
    if name.isEmpty { name = sanitized(base).isEmpty ? "photograph" : sanitized(base) }
    return name + "." + format.fileExtension
  }
  /// Capture date as yyyy-MM-dd when the original recorded one, otherwise the import date.
  static func date(for photo: PhotoRecord) -> String {
    if let captured = photo.capturedAt, captured.count >= 10 {
      let day = captured.prefix(10).replacingOccurrences(of: ":", with: "-")
      if day.filter({ $0 == "-" }).count == 2 { return day }
    }
    let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: photo.importedAt)
  }
  static func sanitized(_ value: String) -> String {
    var cleaned = value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    cleaned = cleaned.components(separatedBy: .controlCharacters).joined()
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    while cleaned.hasPrefix(".") { cleaned.removeFirst() }
    return String(cleaned.prefix(200))
  }
  /// Returns the file to write, or nil when the policy says to skip an existing file.
  public static func resolve(_ url: URL, policy: ExportConflictPolicy, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL? {
    guard exists(url) else { return url }
    switch policy {
    case .skip: return nil
    case .replace: return url
    case .keepBoth:
      let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension, folder = url.deletingLastPathComponent()
      for suffix in 1...9999 {
        let candidate = folder.appendingPathComponent("\(base)-\(suffix)").appendingPathExtension(ext)
        if !exists(candidate) { return candidate }
      }
      return nil
    }
  }
}

/// Writes rendered bytes to disk without re-encoding, attaching metadata according to the policy.
public enum ExportWriter {
  public struct Descriptive: Sendable, Equatable {
    public var caption: String
    public var keywords: [String]
    public init(caption: String, keywords: [String]) { self.caption = caption; self.keywords = keywords }
  }
  public static func write(_ rendered: RenderedResult, to url: URL, policy: ExportMetadataPolicy, includeLocation: Bool,
    original: OriginalReference?, descriptive: Descriptive) throws {
    guard let source = CGImageSourceCreateWithData(rendered.data as CFData, nil),
      let type = CGImageSourceGetType(source) else { throw ExportError.write("The rendered image could not be read back.") }
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).\(url.pathExtension)")
    guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, type, 1, nil) else {
      throw ExportError.destinationUnavailable
    }
    // ImageIO requires either metadata to write or an explicit exclusion; the None policy excludes everything.
    var options: [CFString: Any] = [:]
    if let metadata = metadata(policy: policy, includeLocation: includeLocation, original: original, descriptive: descriptive) {
      options[kCGImageDestinationMetadata] = metadata
      options[kCGImageDestinationMergeMetadata] = false
      if !includeLocation { options[kCGImageMetadataShouldExcludeGPS] = true }
    } else {
      options[kCGImageMetadataShouldExcludeXMP] = true
      options[kCGImageMetadataShouldExcludeGPS] = true
    }
    var failure: Unmanaged<CFError>?
    guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &failure) else {
      try? FileManager.default.removeItem(at: temporary)
      throw ExportError.write(failure?.takeRetainedValue().localizedDescription ?? "unknown error")
    }
    do {
      if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary) }
      else { try FileManager.default.moveItem(at: temporary, to: url) }
    } catch {
      try? FileManager.default.removeItem(at: temporary)
      throw ExportError.write(error.localizedDescription)
    }
  }

  /// Builds the XMP/EXIF metadata for one export. Orientation and pixel-dimension tags never carry over: the render is already oriented.
  static func metadata(policy: ExportMetadataPolicy, includeLocation: Bool, original: OriginalReference?, descriptive: Descriptive) -> CGImageMetadata? {
    let mutable: CGMutableImageMetadata
    switch policy {
    case .none: return nil
    case .descriptive: mutable = CGImageMetadataCreateMutable()
    case .camera:
      if let original, let existing = originalMetadata(original) {
        mutable = CGImageMetadataCreateMutableCopy(existing) ?? CGImageMetadataCreateMutable()
      } else { mutable = CGImageMetadataCreateMutable() }
      var stale = ["tiff:Orientation", "exif:PixelXDimension", "exif:PixelYDimension", "tiff:ImageWidth", "tiff:ImageLength", "exif:ImageWidth", "exif:ImageLength"]
      if !includeLocation {
        CGImageMetadataEnumerateTagsUsingBlock(mutable, nil, [kCGImageMetadataEnumerateRecursively: false] as CFDictionary) { path, _ in
          if (path as String).contains("GPS") { stale.append(path as String) }
          return true
        }
      }
      for path in stale { CGImageMetadataRemoveTagWithPath(mutable, nil, path as CFString) }
    }
    let caption = descriptive.caption.trimmingCharacters(in: .whitespacesAndNewlines)
    if !caption.isEmpty, let tag = CGImageMetadataTagCreate(kCGImageMetadataNamespaceDublinCore, kCGImageMetadataPrefixDublinCore,
      "description" as CFString, .string, caption as CFString) {
      CGImageMetadataSetTagWithPath(mutable, nil, "dc:description" as CFString, tag)
    }
    let keywords = descriptive.keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    if !keywords.isEmpty, let tag = CGImageMetadataTagCreate(kCGImageMetadataNamespaceDublinCore, kCGImageMetadataPrefixDublinCore,
      "subject" as CFString, .arrayUnordered, keywords as CFArray) {
      CGImageMetadataSetTagWithPath(mutable, nil, "dc:subject" as CFString, tag)
    }
    return mutable
  }
  static func originalMetadata(_ original: OriginalReference) -> CGImageMetadata? {
    var url = original.url
    if let bookmark = original.bookmark {
      var stale = false
      if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale) { url = resolved }
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCopyMetadataAtIndex(source, 0, nil)
  }
}
