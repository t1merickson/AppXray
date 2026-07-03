import XCTest

final class DirectoryScanTests: XCTestCase {
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

  private func scan(_ fixture: BundleFixture) -> DetectedTechnologies {
    BundleFeatureDetectionOperation(fixture.root)
      .processDirectoryContents(fixture.root)
  }

  func testElectronFrameworkDetectsElectronAndJavaScript() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/Electron Framework.framework")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.electron))
    XCTAssertTrue(detected.contains(.javascript))
  }

  func testElectronAsarDetectsElectronAndJavaScript() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/app.asar")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.electron))
    XCTAssertTrue(detected.contains(.javascript))
  }

  func testChromiumEmbeddedFrameworkDetectsCEF() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/Chromium Embedded Framework.framework")

    XCTAssertTrue(scan(fixture).contains(.cef))
  }

  func testGoogleChromeFrameworkDetectsChromium() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/Google Chrome Framework.framework")

    XCTAssertTrue(scan(fixture).contains(.chromium))
  }

  func testLibxulDetectsGecko() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/libxul.dylib")

    XCTAssertTrue(scan(fixture).contains(.gecko))
  }

  func testOmniJarDetectsGecko() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/omni.ja")

    XCTAssertTrue(scan(fixture).contains(.gecko))
  }

  func testQtCoreFrameworkDetectsQt() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/QtCore.framework")

    XCTAssertTrue(scan(fixture).contains(.qt))
  }

  func testQt6DylibDetectsQt() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/libQt6Core.6.dylib")

    XCTAssertTrue(scan(fixture).contains(.qt))
  }

  func testQtFrameworkInNonStandardLocationDetectsQt() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Qt/lib/QtWidgets.framework")

    XCTAssertTrue(scan(fixture).contains(.qt))
  }

  func testGtkDylibDetectsGTK() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/libgtk-3.0.dylib")

    XCTAssertTrue(scan(fixture).contains(.gtk))
  }

  func testGlibDylibDoesNotDetectGTK() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/libglib-2.0.dylib")

    XCTAssertFalse(scan(fixture).contains(.gtk))
  }

  func testReactFrameworkDetectsReactNativeAndJavaScript() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/React.framework")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.reactNative))
    XCTAssertTrue(detected.contains(.javascript))
  }

  func testHermesFrameworkDetectsReactNative() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/Hermes.framework")

    XCTAssertTrue(scan(fixture).contains(.reactNative))
  }

  func testSparkleFrameworkDetectsSparkle() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/Sparkle.framework")

    XCTAssertTrue(scan(fixture).contains(.sparkle))
  }

  func testUnityGlobalGameManagersDetectsUnity() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/Data/globalgamemanagers")

    XCTAssertTrue(scan(fixture).contains(.unity))
  }

  func testGodotPckDetectsGodot() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/game.pck")

    XCTAssertTrue(scan(fixture).contains(.godot))
  }

  func testUE5DirectoryDetectsUnrealAndCPlusPlus() throws {
    let fixture = try makeFixture()
    try fixture.mkdir("Contents/UE5")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.unreal))
    XCTAssertTrue(detected.contains(.cplusplus))
  }

  func testMonoBundleDetectsMonoAndDotnet() throws {
    let fixture = try makeFixture()
    try fixture.mkdir("Contents/MonoBundle")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.mono))
    XCTAssertTrue(detected.contains(.dotnet))
  }

  func testCoreClrDylibDetectsDotnet() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Frameworks/libcoreclr.dylib")

    XCTAssertTrue(scan(fixture).contains(.dotnet))
  }

  func testAvaloniaDllDetectsAvaloniaAndDotnet() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/Avalonia.dll")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.avalonia))
    XCTAssertTrue(detected.contains(.dotnet))
  }

  func testJavaDirectoryDetectsJava() throws {
    let fixture = try makeFixture()
    try fixture.mkdir("Contents/Java")

    XCTAssertTrue(scan(fixture).contains(.java))
  }

  func testJPackageRuntimeDetectsJava() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/runtime/Contents/Home/lib/libjvm.dylib")

    XCTAssertTrue(scan(fixture).contains(.java))
  }

  func testJarInAppDirectoryDetectsJava() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/app/tool.jar")

    XCTAssertTrue(scan(fixture).contains(.java))
  }

  func testCompiledScriptDetectsAppleScript() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/Scripts/main.scpt")

    XCTAssertTrue(scan(fixture).contains(.applescript))
  }

  func testPlatypusMarkersDetectPlatypus() throws {
    let fixture = try makeFixture()
    try fixture.touch("Contents/Resources/AppSettings.plist")
    try fixture.touch("Contents/Resources/script")

    XCTAssertTrue(scan(fixture).contains(.platypus))
  }

  func testWrapperDirectoryDetectsIOSOnMacAndUIKit() throws {
    let fixture = try makeFixture()
    try fixture.mkdir("Wrapper")

    let detected = scan(fixture)

    XCTAssertTrue(detected.contains(.iOSOnMac))
    XCTAssertTrue(detected.contains(.uikit))
  }

  func testEmptyBundleDetectsNoTechnologies() throws {
    let fixture = try makeFixture()

    XCTAssertTrue(scan(fixture).isEmpty)
  }
}
