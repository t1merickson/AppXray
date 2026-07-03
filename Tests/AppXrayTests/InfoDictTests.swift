import XCTest

final class InfoDictTests: XCTestCase {
  private var fixtures = [BundleFixture]()

  override func tearDown() {
    fixtures.forEach { $0.destroy() }
    fixtures.removeAll()
    super.tearDown()
  }

  private func makeFixture() throws -> BundleFixture {
    let fixture = try BundleFixture()
    fixtures.append(fixture)
    return fixture
  }

  private func operation(_ fixture: BundleFixture) -> BundleFeatureDetectionOperation {
    BundleFeatureDetectionOperation(fixture.root)
  }

  func testElectronAsarIntegrityDetectsElectronAndJavaScript() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["ElectronAsarIntegrity": ["x": 1]])

    let detected = operation(fixture).processInfoDict(info)

    XCTAssertTrue(detected.contains(.electron))
    XCTAssertTrue(detected.contains(.javascript))
  }

  func testIPhonePlatformNameDetectsIOSOnMacAndUIKit() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["DTPlatformName": "iphoneos"])

    let detected = operation(fixture).processInfoDict(info)

    XCTAssertTrue(detected.contains(.iOSOnMac))
    XCTAssertTrue(detected.contains(.uikit))
  }

  func testIPhonePlatformNameDeterminesIOSPlatform() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["DTPlatformName": "iphoneos"])

    let platform = operation(fixture)
      .determinePlatform(info: info, bundleURL: fixture.root)

    XCTAssertEqual(platform, .iOS)
  }

  func testAutomatorAppletKeyDetectsAutomator() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["AMIsApplet": true])

    XCTAssertTrue(operation(fixture).processInfoDict(info).contains(.automator))
  }

  func testCarbonRequirementDetectsCarbon() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["LSRequiresCarbon": 1])

    XCTAssertTrue(operation(fixture).processInfoDict(info).contains(.carbon))
  }

  func testJavaXKeyDetectsJava() throws {
    let fixture = try makeFixture()
    let info = InfoDict(["JavaX": [:]])

    XCTAssertTrue(operation(fixture).processInfoDict(info).contains(.java))
  }

  func testIOSDeviceFamilyWithMinimumOSVersionDeterminesCatalyst() throws {
    let fixture = try makeFixture()
    let info = InfoDict([
      "UIDeviceFamily": [2],
      "MinimumOSVersion": "14.0",
    ])

    let platform = operation(fixture)
      .determinePlatform(info: info, bundleURL: fixture.root)

    XCTAssertEqual(platform, .catalyst)
  }

  func testEmptyInfoDeterminesMacOS() throws {
    let fixture = try makeFixture()
    let info = InfoDict([:])

    let platform = operation(fixture)
      .determinePlatform(info: info, bundleURL: fixture.root)

    XCTAssertEqual(platform, .macOS)
  }
}
