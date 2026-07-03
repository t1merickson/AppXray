import XCTest

final class DependencyScanTests: XCTestCase {
  private func scan(_ dependencies: [String]) -> DetectedTechnologies {
    var detected = DetectedTechnologies()
    detected.scanDependencies(dependencies)
    return detected
  }

  func testLibSwiftCoreDetectsSwift() {
    XCTAssertTrue(scan(["/usr/lib/swift/libswiftCore.dylib"]).contains(.swift))
  }

  func testLibObjcDetectsObjectiveC() {
    XCTAssertTrue(scan(["/usr/lib/libobjc.A.dylib"]).contains(.objc))
  }

  func testLibCPlusPlusDetectsCPlusPlus() {
    XCTAssertTrue(scan(["/usr/lib/libc++.1.dylib"]).contains(.cplusplus))
  }

  func testAppKitFrameworkDetectsAppKit() {
    XCTAssertTrue(scan(["/System/Library/Frameworks/AppKit.framework/AppKit"])
      .contains(.appkit))
  }

  func testSwiftUIFrameworkDetectsSwiftUI() {
    XCTAssertTrue(scan(["/System/Library/Frameworks/SwiftUI.framework/SwiftUI"])
      .contains(.swiftui))
  }

  func testQtCoreDependencyDetectsQt() {
    XCTAssertTrue(scan(["@rpath/libQt5Core.5.dylib"]).contains(.qt))
  }

  func testSparkleFrameworkDetectsSparkle() {
    XCTAssertTrue(scan(["@rpath/Sparkle.framework/Sparkle"]).contains(.sparkle))
  }

  func testRealisticDependencyListSetsUnion() {
    let detected = scan([
      "/System/Library/Frameworks/AppKit.framework/AppKit",
      "/usr/lib/swift/libswiftCore.dylib",
      "@rpath/Sparkle.framework/Sparkle",
      "@rpath/libQt5Core.5.dylib",
    ])

    XCTAssertTrue(detected.contains(.appkit))
    XCTAssertTrue(detected.contains(.swift))
    XCTAssertTrue(detected.contains(.sparkle))
    XCTAssertTrue(detected.contains(.qt))
  }

  func testEmptyDependencyListDetectsNoTechnologies() {
    XCTAssertTrue(scan([]).isEmpty)
  }
}
