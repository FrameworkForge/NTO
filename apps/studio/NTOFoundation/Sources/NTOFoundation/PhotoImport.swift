import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

public enum PhotoError: LocalizedError, Sendable {
  case unsupported(String), unreadable(String), missingOriginal(String), changedOriginal(String)
  case wrongOriginal, projectMissing, notReferenced, previewFailed, invalidManagedPath
  public var errorDescription: String? {
    switch self {
    case .unsupported(let name): "\(name) is not a supported JPEG, HEIC, TIFF, or RAW photograph."
    case .unreadable(let name): "\(name) could not be decoded. Check that the file is complete and this macOS version supports its camera format."
    case .missingOriginal(let name): "The original for \(name) is unavailable. Reconnect its drive or locate the original file."
    case .changedOriginal(let name): "\(name) changed since import. Locate the unchanged original or import the changed file separately."
    case .wrongOriginal: "This file does not match the imported photograph. Choose the original file, even if its name has changed."
    case .projectMissing: "Choose an existing project before importing."
    case .notReferenced: "Only referenced originals can be relocated. Restore a missing managed original from your backup."
    case .previewFailed: "A preview could not be created. Check available disk space and retry."
    case .invalidManagedPath: "The managed original location is invalid."
    }
  }
}

public enum ImportStorage: String, CaseIterable, Sendable {
  case copy = "Copy into Studio", reference = "Reference in place"
}
public struct ImportCandidate: Sendable {
  public let url: URL
}
public struct ImportDiscovery: Sendable {
  public var candidates: [ImportCandidate] = []
  public var issues: [String] = []
}
public struct LibraryLocations: Sendable {
  public let root: URL
  public var originals: URL { root.appendingPathComponent("Originals", isDirectory: true) }
  public var cache: URL { root.appendingPathComponent("PreviewCache", isDirectory: true) }
  public var presets: URL { root.appendingPathComponent("Presets", isDirectory: true) }
  public init(root: URL) { self.root = root }
  public static func standard() throws -> Self {
    let support = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    return Self(root: support.appendingPathComponent("NTO/Studio", isDirectory: true))
  }
  public func managedURL(_ path: String) throws -> URL {
    let url = originals.appendingPathComponent(path).standardizedFileURL
    guard url.path.hasPrefix(originals.standardizedFileURL.path + "/") else {
      throw PhotoError.invalidManagedPath
    }
    return url
  }
}

/// Serialized disk work runs on this actor, not on the main actor.
public actor PhotoImportWorker {
  public let locations: LibraryLocations
  public init(locations: LibraryLocations) { self.locations = locations }

  public func discover(_ urls: [URL]) throws -> ImportDiscovery {
    var result = ImportDiscovery()
    var seen: Set<String> = []
    func append(_ url: URL) throws {
      try Task.checkCancellation()
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      // Do not follow symlinks outside a user-selected directory.
      guard values.isRegularFile == true, values.isSymbolicLink != true else { return }
      if seen.insert(url.standardizedFileURL.path).inserted {
        result.candidates.append(ImportCandidate(url: url))
      }
    }
    for url in urls {
      try Task.checkCancellation()
      do {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
          result.issues.append("\(url.lastPathComponent): choose the original instead of a symbolic link.")
          continue
        }
        if values.isDirectory == true {
          // Enumerate explicitly so an unreadable nested folder is reported, never silently ignored.
          var folders = [url]
          while let folder = folders.popLast() {
            try Task.checkCancellation()
            do {
              for child in try FileManager.default.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                options: [.skipsHiddenFiles]) {
                let info = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
                if info.isSymbolicLink == true || info.isPackage == true { continue }
                if info.isDirectory == true { folders.append(child) } else { try append(child) }
              }
            } catch is CancellationError { throw CancellationError() }
            catch { result.issues.append("\(folder.lastPathComponent): \(error.localizedDescription)") }
          }
        } else { try append(url) }
      } catch is CancellationError { throw CancellationError() }
      catch { result.issues.append("\(url.lastPathComponent): \(error.localizedDescription)") }
    }
    result.candidates.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
    return result
  }

  public func inspect(_ candidate: ImportCandidate, caption: String) throws -> PhotoRecord {
    let url = candidate.url
    try Task.checkCancellation()
    guard let source = CGImageSourceCreateWithURL(url as CFURL,
      [kCGImageSourceShouldCache: false] as CFDictionary),
      let identifier = CGImageSourceGetType(source) as String?, let type = UTType(identifier),
      type.conforms(to: .jpeg) || type.conforms(to: .heic) || type.conforms(to: .tiff) || type.conforms(to: .rawImage)
    else { throw PhotoError.unsupported(url.lastPathComponent) }
    guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
      let width = props[kCGImagePropertyPixelWidth as String] as? Int,
      let height = props[kCGImagePropertyPixelHeight as String] as? Int, width > 0, height > 0
    else { throw PhotoError.unreadable(url.lastPathComponent) }
    let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    let fingerprint = try Self.fingerprint(url)
    let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate
    else { throw PhotoError.changedOriginal(url.lastPathComponent) }
    let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    let orientation = props[kCGImagePropertyOrientation as String] as? Int ?? 1
    let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first
    var exposure: [String] = []
    if let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber { exposure.append("ƒ/\(aperture)") }
    if let shutter = exif[kCGImagePropertyExifExposureTime as String] as? Double,
      shutter.isFinite, shutter > 0, (1 / shutter).isFinite {
      exposure.append(shutter < 1 ? String(format: "1/%.0f s", 1 / shutter) : "\(shutter) s")
    }
    if let iso { exposure.append("ISO \(iso)") }
    if let focal = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber { exposure.append("\(focal) mm") }
    return PhotoRecord(id: UUID(), fingerprint: fingerprint, filename: url.lastPathComponent,
      mediaType: identifier, width: orientation >= 5 ? height : width,
      height: orientation >= 5 ? width : height, byteCount: Int64(after.fileSize ?? 0),
      capturedAt: exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
      camera: tiff[kCGImagePropertyTIFFModel as String] as? String,
      lens: exif[kCGImagePropertyExifLensModel as String] as? String,
      exposure: exposure.isEmpty ? nil : exposure.joined(separator: " · "), caption: caption)
  }

  public func prepare(_ record: PhotoRecord, source: URL, storage: ImportStorage) throws -> PhotoRecord {
    try Task.checkCancellation()
    var photo = record
    if storage == .reference {
      photo.bookmark = try Self.bookmark(source)
      return photo
    }
    let folder = locations.originals.appendingPathComponent(record.id.uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    do {
      let target = folder.appendingPathComponent("original.\(source.pathExtension.lowercased())")
      let partial = folder.appendingPathComponent("import.partial")
      let input = try FileHandle(forReadingFrom: source)
      defer { try? input.close() }
      guard FileManager.default.createFile(atPath: partial.path, contents: nil) else { throw PhotoError.previewFailed }
      let output = try FileHandle(forWritingTo: partial)
      defer { try? output.close() }
      var hash = SHA256()
      while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
        try Task.checkCancellation()
        hash.update(data: data)
        try output.write(contentsOf: data)
      }
      try output.synchronize()
      guard Self.hex(hash.finalize()) == record.fingerprint else { throw PhotoError.changedOriginal(record.filename) }
      try Task.checkCancellation()
      try FileManager.default.moveItem(at: partial, to: target)
      photo.managedPath = "\(record.id.uuidString)/\(target.lastPathComponent)"
      return photo
    } catch {
      try? FileManager.default.removeItem(at: folder)
      throw error
    }
  }

  public func discard(_ photo: PhotoRecord) throws {
    guard let path = photo.managedPath else { return }
    try FileManager.default.removeItem(at: locations.managedURL(path).deletingLastPathComponent())
  }
  /// Only uncommitted UUID directories owned by this library are removed after a crashed import.
  public func recoverUncommittedCopies(keeping paths: Set<String>) throws {
    try FileManager.default.createDirectory(at: locations.originals, withIntermediateDirectories: true)
    let keep = Set(paths.map { String($0.split(separator: "/")[0]) })
    for folder in try FileManager.default.contentsOfDirectory(at: locations.originals,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
      let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard UUID(uuidString: folder.lastPathComponent) != nil, !keep.contains(folder.lastPathComponent),
        values.isDirectory == true, values.isSymbolicLink != true else { continue }
      try FileManager.default.removeItem(at: folder)
    }
  }
  public func verifiedBookmark(for url: URL, matching fingerprint: String) throws -> Data {
    guard try Self.fingerprint(url) == fingerprint else { throw PhotoError.wrongOriginal }
    return try Self.bookmark(url)
  }
  static func bookmark(_ url: URL) throws -> Data {
    try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
      includingResourceValuesForKeys: nil, relativeTo: nil)
  }
  static func fingerprint(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty {
      try Task.checkCancellation(); hash.update(data: bytes)
    }
    return hex(hash.finalize())
  }
  private static func hex(_ digest: SHA256.Digest) -> String { digest.map { String(format: "%02x", $0) }.joined() }
}

func withOriginal<T>(_ photo: PhotoRecord, locations: LibraryLocations, body: (URL) throws -> T) throws -> T {
  let url: URL
  if let path = photo.managedPath { url = try locations.managedURL(path) }
  else if let bookmark = photo.bookmark {
    var stale = false
    do {
      url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
        relativeTo: nil, bookmarkDataIsStale: &stale)
    } catch { throw PhotoError.missingOriginal(photo.filename) }
  } else { throw PhotoError.missingOriginal(photo.filename) }
  let scoped = url.startAccessingSecurityScopedResource()
  defer { if scoped { url.stopAccessingSecurityScopedResource() } }
  guard FileManager.default.isReadableFile(atPath: url.path) else { throw PhotoError.missingOriginal(photo.filename) }
  return try body(url)
}
