import XCTest

final class BinaryStringTests: XCTestCase {
  private var temporaryFiles = [URL]()

  override func tearDown() {
    temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) }
    temporaryFiles.removeAll()
    super.tearDown()
  }

  private func writeBinary(strings: [String]) throws -> URL {
    var data = Data()
    for string in strings {
      data.append(Data(string.utf8))
      data.append(contentsOf: [0])
    }
    return try writeBinary(data)
  }

  private func writeBinary(_ data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try data.write(to: url)
    temporaryFiles.append(url)
    return url
  }

  private func detect(_ strings: [String],
                      current: DetectedTechnologies = []) throws -> DetectedTechnologies
  {
    let url = try writeBinary(strings: strings)
    return BundleFeatureDetectionOperation(url)
      .binaryStringFeatures(url, current: current)
  }

  func testRustBacktraceDetectsRust() throws {
    XCTAssertTrue(try detect(["RUST_BACKTRACE"]).contains(.rust))
  }

  func testGoBuildIDDetectsGo() throws {
    XCTAssertTrue(try detect(["Go build ID:"]).contains(.go))
  }

  func testGodotMarkersDetectGodot() throws {
    XCTAssertTrue(try detect(["GDPC", "res://"]).contains(.godot))
  }

  func testGDPCWithoutResourcePathDoesNotDetectGodot() throws {
    XCTAssertFalse(try detect(["GDPC"]).contains(.godot))
  }

  func testTauriMarkerDetectsTauriAndRust() throws {
    let detected = try detect(["tauri://"])

    XCTAssertTrue(detected.contains(.tauri))
    XCTAssertTrue(detected.contains(.rust))
  }

  func testDotnetBundleMarkerDetectsDotnet() throws {
    XCTAssertTrue(try detect(["DOTNET_BUNDLE_EXTRACT_BASE_DIR"]).contains(.dotnet))
  }

  func testKotlinMarkerDetectsKotlin() throws {
    XCTAssertTrue(try detect(["kfun:"]).contains(.kotlin))
  }

  func testQtVersionTagDetectsQt() throws {
    XCTAssertTrue(try detect(["qt_version_tag"]).contains(.qt))
  }

  func testBinaryStringScanSkipsWhenDefinitiveFrameworkAlreadyDetected() throws {
    let detected = try detect(["RUST_BACKTRACE", "Go build ID:"], current: [.electron])

    XCTAssertTrue(detected.isEmpty)
  }

  func testExtractPrintableStringsUsesMinimumRunLengthOfFour() throws {
    let data = Data([97, 98, 99, 0, 97, 98, 99, 100, 0])
    let strings = BundleFeatureDetectionOperation(try writeBinary(data))
      .extractPrintableStrings(from: data)

    XCTAssertTrue(strings.components(separatedBy: .newlines).contains("abcd"))
    XCTAssertFalse(strings.components(separatedBy: .newlines).contains("abc"))
  }
}
