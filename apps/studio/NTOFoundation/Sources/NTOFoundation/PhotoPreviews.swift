import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Disk and decoded-image caches are bounded independently. No full-resolution images enter the grid.
public actor PhotoPreviews {
  private let locations: LibraryLocations
  private let memory = NSCache<NSString, CGImage>()
  private var disk: [String: (bytes: Int, accessed: Date)] = [:]
  private var indexed = false
  private let diskLimit: Int
  public init(locations: LibraryLocations, diskLimit: Int = 256 * 1024 * 1024) {
    self.locations = locations; self.diskLimit = diskLimit
    memory.totalCostLimit = 64 * 1024 * 1024
    memory.countLimit = 300
  }
  private func index() throws {
    guard !indexed else { return }
    try FileManager.default.createDirectory(at: locations.cache, withIntermediateDirectories: true)
    for file in try FileManager.default.contentsOfDirectory(at: locations.cache,
      includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) where file.pathExtension == "jpg" {
      let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
      disk[file.lastPathComponent] = (values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
    }
    indexed = true
    try trim()
  }
  public func image(for photo: PhotoRecord, maxPixel: Int = 512) throws -> CGImage {
    try Task.checkCancellation()
    try index()
    let size = min(max(maxPixel, 128), 2400)
    let key = "\(photo.fingerprint)-original-v1-\(size).jpg"
    if let cached = memory.object(forKey: key as NSString) { return cached }
    let file = locations.cache.appendingPathComponent(key)
    let image: CGImage
    if disk[key] != nil, let source = CGImageSourceCreateWithURL(file as CFURL, nil),
      let cached = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) {
      image = cached
      disk[key]?.accessed = .now
    } else {
      image = try withOriginal(photo, locations: locations) { url in
        // Verify a reference before generating new derived output. A cached preview can still be
        // displayed while a drive is disconnected, but a changed source cannot replace its identity.
        if photo.isReferenced, try PhotoImportWorker.fingerprint(url) != photo.fingerprint {
          throw PhotoError.changedOriginal(photo.filename)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL,
          [kCGImageSourceShouldCache: false] as CFDictionary),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceShouldCacheImmediately: true
          ] as CFDictionary) else { throw PhotoError.unreadable(photo.filename) }
        return image
      }
      try Task.checkCancellation()
      let data = NSMutableData()
      guard let target = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw PhotoError.previewFailed
      }
      CGImageDestinationAddImage(target, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
      guard CGImageDestinationFinalize(target) else { throw PhotoError.previewFailed }
      try (data as Data).write(to: file, options: .atomic)
      disk[key] = (data.length, .now)
      try trim()
    }
    memory.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height)
    return image
  }
  public func originalStatus(_ photo: PhotoRecord) -> String? {
    do { try withOriginal(photo, locations: locations) { _ in () }; return nil }
    catch { return error.localizedDescription }
  }
  private func trim() throws {
    var bytes = disk.values.reduce(0) { $0 + $1.bytes }
    guard bytes > diskLimit else { return }
    for entry in disk.sorted(by: { $0.value.accessed < $1.value.accessed }) {
      try FileManager.default.removeItem(at: locations.cache.appendingPathComponent(entry.key))
      disk.removeValue(forKey: entry.key)
      bytes -= entry.value.bytes
      if bytes <= diskLimit { break }
    }
  }
  public func cachedByteCount() throws -> Int { try index(); return disk.values.reduce(0) { $0 + $1.bytes } }
}
