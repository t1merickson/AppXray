import Foundation

/// Builds a throwaway fake .app directory tree for detection tests.
final class BundleFixture {
  let root: URL   // ".../<uuid>/Fake.app"

  init() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("Fake.app")
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Contents"),
      withIntermediateDirectories: true)
  }

  /// Creates an empty file (intermediate dirs included) at a path relative
  /// to the bundle root, e.g. "Contents/Frameworks/Electron Framework.framework".
  @discardableResult
  func touch(_ relativePath: String, contents: Data = Data()) throws -> URL {
    let url = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try contents.write(to: url)
    return url
  }

  /// Creates a directory at a bundle-root-relative path.
  @discardableResult
  func mkdir(_ relativePath: String) throws -> URL {
    let url = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true)
    return url
  }

  func destroy() {
    try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
  }
}
