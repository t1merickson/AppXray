//
//  BundleFeatureDetectionOperation.swift
//  5 GUIs
//

import SwiftUI

protocol BundleFeatureDetectionOperationDelegate: AnyObject {
  func detectionStateDidChange(_ state: BundleFeatureDetectionOperation)
}

/// Runs the four-phase detection pipeline on a background queue:
///  1. Bundle structure scan (filesystem checks, no process spawning)
///  2. Info.plist analysis (already loaded by Bundle)
///  3. Dependency analysis (objdump on executable + transitive deps)
///  4. Binary string analysis (only for Tauri/Rust when ambiguous)
final class BundleFeatureDetectionOperation: ObservableObject {

  weak var delegate : BundleFeatureDetectionOperationDelegate?

  enum State: Equatable {
    case processing
    case failedToOpen(Swift.Error?)
    case notAnApplication
    case finished
    static func == (lhs: State, rhs: State) -> Bool {
      switch ( lhs, rhs ) {
        case ( .processing       , .processing       ): return true
        case ( .failedToOpen     , .failedToOpen     ): return true
        case ( .notAnApplication , .notAnApplication ): return true
        case ( .finished         , .finished         ): return true
        default: return false
      }
    }
  }

  let fm = FileManager.default

  @Published var state = State.processing {
    didSet {
      assert(_dispatchPreconditionTest(.onQueue(.main)))
      delegate?.detectionStateDidChange(self)
    }
  }
  @Published var info : ExecutableFileTechnologyInfo {
    didSet {
      assert(_dispatchPreconditionTest(.onQueue(.main)))
      delegate?.detectionStateDidChange(self)
    }
  }
  @Published var otoolAvailable = true

  let url : URL

  private let nesting : Int

  init(_ url: URL, nesting: Int = 1) {
    self.url     = url
    self.info    = ExecutableFileTechnologyInfo(fileURL: url)
    self.nesting = nesting
  }
  func resume() {
    DispatchQueue.global().async {
      self.startWork()
    }
  }


  // MARK: - Thread-safe helpers

  private func apply(_ block: @escaping () -> Void) {
    RunLoop.main.perform(block)
  }
  private func apply<V>(_ keyPath:
                            ReferenceWritableKeyPath<BundleFeatureDetectionOperation, V>,
                        _ value: V)
  {
    apply {
      self[keyPath: keyPath] = value
    }
  }
  private func applyState(_ state: State) {
    apply(\.state, state)
  }


  // MARK: - Main Entry

  private func startWork() {

    var isDir : ObjCBool = false
    guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
      return applyState(.failedToOpen(nil))
    }

    if isDir.boolValue {
      processWrapper(url)
    }
    else {
      processFile(url)
    }
  }


  // MARK: - Workers

  private func processFile(_ url: URL) {
    guard fm.isExecutableFile(atPath: url.path) else {
      return applyState(.notAnApplication)
    }

    apply(\.info.executableURL, url)

    processExecutable(url)

    applyState(.finished)
  }

  /// Processes an app bundle on a background queue. Runs all four detection
  /// phases, loads the icon, and scans any nested applications.
  private func processWrapper(_ url: URL) {
    guard let bundle = Bundle(url: url) else {
      print("could not open bundle:", url)
      return applyState(.failedToOpen(nil))
    }

    let info = InfoDict(bundle.infoDictionary ?? [:])

    guard let executableURL = bundle.executableURL else {
      print("no executable in bundle:", bundle)
      return applyState(.notAnApplication)
    }
    let receiptURL = bundle.appStoreReceiptURL

    apply {
      self.info.executableURL  = executableURL
      self.info.receiptURL     = receiptURL
      self.info.infoDictionary = info
    }

    let image = loadImage(in: info, bundle: bundle)
    apply(\.info.appImage, image)

    // Phase 1: Bundle structure scan (fast, no process spawning)
    let bundleFeatures = processDirectoryContents(url)

    // Phase 2: Info.plist analysis
    let plistFeatures = processInfoDict(info)

    // Determine platform type
    let platform = determinePlatform(info: info, bundleURL: url)
    apply(\.info.platformType, platform)

    // Phase 3: Dependency analysis (objdump)
    processExecutable(executableURL)

    // Merge Phase 1 & 2 results
    let earlyFeatures = bundleFeatures.union(plistFeatures)
    if !earlyFeatures.isEmpty {
      apply {
        self.info.detectedTechnologies.formUnion(earlyFeatures)
      }
    }

    // Phase 4: Binary string analysis (selective, only when needed)
    processBinaryStrings(executableURL)

    // Scan nested applications
    if nesting < 2 {
      processNestedApplications(ownExecutable: info.executable
                                            ?? executableURL.lastPathComponent)
    }

    applyState(.finished)
  }


  // MARK: - Phase 1: Bundle Structure Scan

  /// Scans the bundle directory structure for framework and file markers.
  /// This is the fastest detection phase -- pure filesystem checks.
  private func processDirectoryContents(_ url: URL) -> DetectedTechnologies {
    var detected = DetectedTechnologies()
    let contents = url.appendingPathComponent("Contents")

    // --- Frameworks directory scan ---
    let frameworksURL = contents.appendingPathComponent("Frameworks")
    let frameworkFiles = fm.ls(frameworksURL)

    for filename in frameworkFiles {
      // Electron
      if filename == "Electron Framework.framework" {
        detected.insert(.electron)
        detected.insert(.javascript)
        continue
      }
      // CEF (Chromium Embedded Framework) -- e.g. Spotify
      if filename == "Chromium Embedded Framework.framework" {
        detected.insert(.cef)
        continue
      }
      // Flutter
      if filename == "FlutterMacOS.framework" {
        detected.insert(.flutter)
        continue
      }
      // Qt
      if filename.hasPrefix("QtCore") && filename.hasSuffix(".framework") {
        detected.insert(.qt)
        continue
      }
      if filename.hasPrefix("QtGui") && filename.hasSuffix(".framework") {
        detected.insert(.qt)
        continue
      }
      // Capacitor / Ionic
      if filename == "Capacitor.framework" || filename == "Cordova.framework" {
        detected.insert(.capacitor)
        detected.insert(.javascript)
        continue
      }
      // React Native
      if filename == "React.framework"
      || filename == "hermes.framework"
      || filename == "React-Core.framework" {
        detected.insert(.reactNative)
        detected.insert(.javascript)
        continue
      }
      // wxWidgets
      if filename.hasPrefix("libwx_") {
        detected.insert(.wxWidgets)
        continue
      }
      // Python
      if filename == "python-extensions"
      || filename == "Python.framework"
      || filename.hasPrefix("libpython") {
        detected.insert(.python)
        continue
      }
      // Avalonia (.NET)
      if filename == "libAvaloniaNative.dylib" {
        detected.insert(.avalonia)
        detected.insert(.dotnet)
        continue
      }
      // .NET runtime
      if filename == "libcoreclr.dylib" || filename == "libhostfxr.dylib" {
        detected.insert(.dotnet)
        continue
      }
      // Unity
      if filename.hasPrefix("libmonobdwgc") || filename == "UnityPlayer.dylib"
      || filename == "libil2cpp.dylib" {
        detected.insert(.unity)
        continue
      }
    }

    // Also check for .dll files in Frameworks (Avalonia, .NET MAUI)
    for filename in frameworkFiles {
      if filename == "Avalonia.dll" || filename == "Avalonia.Native.dll" {
        detected.insert(.avalonia)
        detected.insert(.dotnet)
      }
      if filename == "Microsoft.Maui.dll" || filename == "Microsoft.Maui.Controls.dll" {
        detected.insert(.dotnet)
      }
    }

    // --- Qt in non-standard location (e.g. Ableton: Contents/Qt/lib/) ---
    if !detected.contains(.qt) {
      let qtLibURL = contents.appendingPathComponent("Qt/lib")
      let qtFiles = fm.ls(qtLibURL)
      for filename in qtFiles {
        if filename.hasPrefix("QtCore") && filename.hasSuffix(".framework") {
          detected.insert(.qt)
          break
        }
      }
    }

    // --- Resources directory checks ---
    let resources = contents.appendingPathComponent("Resources")

    // Electron: app.asar or unpacked app/package.json
    if fm.fileExists(atPath: resources.appendingPathComponent("app.asar").path) {
      detected.insert(.electron)
      detected.insert(.javascript)
    }
    if fm.fileExists(atPath: resources.appendingPathComponent("app/package.json").path) {
      detected.insert(.electron)
      detected.insert(.javascript)
    }

    // Capacitor config
    if fm.fileExists(atPath: resources.appendingPathComponent("capacitor.config.json").path) {
      detected.insert(.capacitor)
      detected.insert(.javascript)
    }

    // Unity: globalgamemanagers
    if fm.fileExists(atPath: resources.appendingPathComponent("Data/globalgamemanagers").path) {
      detected.insert(.unity)
    }

    // Godot: .pck files in Resources
    let resourceFiles = fm.ls(resources)
    for filename in resourceFiles {
      if filename.hasSuffix(".pck") {
        detected.insert(.godot)
        break
      }
    }

    // AppleScript: .scpt files in Resources/Scripts
    let scriptsURL = resources.appendingPathComponent("Scripts")
    if !fm.ls(scriptsURL, suffix: ".scpt").isEmpty {
      detected.insert(.applescript)
    }

    // --- Other content directories ---

    // Java: Contents/Java or Contents/Eclipse
    for dir in [ "Java", "Eclipse" ] {
      if fm.fileExists(atPath: contents.appendingPathComponent(dir).path) {
        detected.insert(.java)
        break
      }
    }

    // Mono/Xamarin: Contents/MonoBundle
    if fm.fileExists(atPath: contents.appendingPathComponent("MonoBundle").path) {
      detected.insert(.mono)
      detected.insert(.dotnet)
    }

    // Platypus: both AppSettings.plist and script in Resources
    let platypusSettings = resources.appendingPathComponent("AppSettings.plist")
    let platypusScript   = resources.appendingPathComponent("script")
    if fm.fileExists(atPath: platypusSettings.path)
    && fm.fileExists(atPath: platypusScript.path) {
      detected.insert(.platypus)
    }

    // iOS on Mac: Wrapper/ directory at top level
    if fm.fileExists(atPath: url.appendingPathComponent("Wrapper").path) {
      detected.insert(.iOSOnMac)
      detected.insert(.uikit)
    }

    return detected
  }


  // MARK: - Phase 2: Info.plist Analysis

  /// Extracts technology signals from the parsed Info.plist.
  private func processInfoDict(_ info: InfoDict) -> DetectedTechnologies {
    var detected = DetectedTechnologies()

    // Electron plist keys
    if info.electronAsarIntegrity {
      detected.insert(.electron)
      detected.insert(.javascript)
    }

    // iOS app running on Mac
    if info.platformName == "iphoneos" {
      detected.insert(.iOSOnMac)
      detected.insert(.uikit)
    }

    // Automator applet
    if info.isAutomatorApplet {
      detected.insert(.automator)
    }

    // Carbon requirement
    if info.requiresCarbon {
      detected.insert(.carbon)
    }

    // Java (JD-GUI style)
    if info.JavaX {
      detected.insert(.java)
    }

    return detected
  }


  // MARK: - Platform Detection

  /// Determines the platform type based on Info.plist and bundle structure.
  private func determinePlatform(info: InfoDict, bundleURL: URL) -> PlatformType {
    // iOS app on Mac (via Wrapper/)
    if fm.fileExists(atPath: bundleURL.appendingPathComponent("Wrapper").path) {
      return .iOS
    }
    // iOS app on Mac (via DTPlatformName)
    if info.platformName == "iphoneos" {
      return .iOS
    }
    // Catalyst hint from UIDeviceFamily
    if !info.deviceFamily.isEmpty && info.minimumOSVersion != nil
       && info.minimumSystemVersion == nil {
      return .catalyst
    }
    return .macOS
  }


  // MARK: - Phase 3: Dependency Analysis

  /// Runs objdump on the executable (with traversal of dependencies).
  private func processExecutable(_ executableURL: URL) {
    do {
      let dependencies = try otool(executableURL)

      var detectedFeatures = DetectedTechnologies()
      detectedFeatures.scanDependencies(dependencies)

      // Detect Catalyst from iOSSupport paths in dependencies
      for dep in dependencies {
        if dep.contains("/System/iOSSupport/") {
          detectedFeatures.insert(.catalyst)
          break
        }
      }

      apply {
        self.otoolAvailable = true
        self.info.dependencies = dependencies
        self.info.detectedTechnologies.formUnion(detectedFeatures)

        // Refine platform type based on Catalyst detection
        if detectedFeatures.contains(.catalyst) && self.info.platformType == .macOS {
          self.info.platformType = .catalyst
        }
      }
    }
    catch {
      print("Could not invoke OTool:", error)
      apply(\.otoolAvailable, false)
    }
  }


  // MARK: - Phase 4: Binary String Analysis

  /// Selectively scans binary strings for Tauri/Rust markers.
  /// Only runs when the app links WebKit but no major framework was identified,
  /// suggesting a possible Tauri app.
  private func processBinaryStrings(_ executableURL: URL) {
    // Read current detected technologies on the background thread.
    // We use a semaphore to safely read the main-thread property.
    var currentTechs = DetectedTechnologies()
    let sem = DispatchSemaphore(value: 0)
    apply {
      currentTechs = self.info.detectedTechnologies
      sem.signal()
    }
    sem.wait()

    // Only run this expensive check if we have WebKit but no identified
    // major framework, which is the Tauri signature pattern.
    let majorFrameworks: DetectedTechnologies = [
      .electron, .cef, .flutter, .qt, .reactNative, .capacitor,
      .unity, .godot, .unreal, .java, .dotnet, .avalonia, .mono
    ]
    let hasWebKit = currentTechs.contains(.webkit)
    let hasMajorFramework = !currentTechs.intersection(majorFrameworks).isEmpty

    guard hasWebKit && !hasMajorFramework else { return }

    // Read a limited portion of the binary and search for markers
    guard let data = try? Data(
      contentsOf: executableURL,
      options: [.mappedIfSafe]
    ) else { return }

    // Search for Tauri markers in the binary
    let tauriMarkers  = ["tauri://", "__TAURI_METADATA__", "__TAURI_IPC__"]
    let rustMarkers   = ["/.cargo/registry", "/rustc/"]

    let binaryString = extractPrintableStrings(from: data, limit: 2_000_000)

    var detected = DetectedTechnologies()

    for marker in tauriMarkers {
      if binaryString.contains(marker) {
        detected.insert(.tauri)
        detected.insert(.rust)
        break
      }
    }

    if !detected.contains(.rust) {
      for marker in rustMarkers {
        if binaryString.contains(marker) {
          detected.insert(.rust)
          break
        }
      }
    }

    if !detected.isEmpty {
      apply {
        self.info.detectedTechnologies.formUnion(detected)
      }
    }
  }

  /// Extracts printable ASCII strings from binary data, similar to `strings(1)`.
  /// Only scans up to `limit` bytes for performance.
  private func extractPrintableStrings(from data: Data, limit: Int) -> String {
    let scanLength = min(data.count, limit)
    var result = ""
    result.reserveCapacity(scanLength / 4)

    var current = ""
    current.reserveCapacity(64)

    for i in 0..<scanLength {
      let byte = data[i]
      if byte >= 0x20 && byte < 0x7F { // printable ASCII
        current.append(Character(UnicodeScalar(byte)))
      } else {
        if current.count >= 4 { // minimum string length like strings(1)
          result.append(current)
          result.append("\n")
        }
        current.removeAll(keepingCapacity: true)
      }
    }
    if current.count >= 4 {
      result.append(current)
    }

    return result
  }


  // MARK: - Nested Applications

  private func processNestedApplications(ownExecutable: String) {
    let contents = url.appendingPathComponent("Contents")

    func scan(_ directory: URL) {
      let apps = fm.ls(directory, suffix: ".app").lazy
        .filter { $0 != ownExecutable }
        .map    { directory.appendingPathComponent($0) }
      for app in apps {
        let op = BundleFeatureDetectionOperation(app, nesting: nesting + 1)
        op.startWork() // same thread (vs resume), no delegate

        if op.info.executableURL  != nil &&
           op.info.infoDictionary != nil &&
           !op.info.detectedTechnologies.isEmpty
        {
          apply {
            self.info.embeddedExecutables.append(op.info)
          }
        }
      }
    }

    scan(contents.appendingPathComponent("MacOS"))
    scan(contents.appendingPathComponent("Frameworks"))
  }
}


// MARK: - FileManager helpers

fileprivate extension FileManager {

  func ls(_ url: URL, suffix: String = "") -> [ String ] {
    (try? contentsOfDirectory(at: url, includingPropertiesForKeys: nil,
                              options: .skipsSubdirectoryDescendants)
      .map    { $0.lastPathComponent }
      .filter { $0.hasSuffix(suffix) }
      .sorted()
    ) ?? []
  }
}


// MARK: - Dependency Scanning

extension DetectedTechnologies {

  mutating func scanDependencies(_ dependencies: [ String ]) {
    for dep in dependencies {
      func check(_ option: DetectedTechnologies, _ needle: String) -> Bool
      {
        guard !contains(option)    else { return false } // scanned already
        guard dep.contains(needle) else { return false }
        self.insert(option)
        return true
      }

      // Frameworks
      if check(.electron,  "Electron Framework")           { continue }
      if check(.cef,       "Chromium Embedded Framework")  { continue }
      if check(.flutter,   "FlutterMacOS")                 { continue }
      if check(.appkit,    "AppKit.framework")             { continue }
      if check(.swiftui,   "SwiftUI.framework")            { continue }
      if check(.uikit,     "UIKit.framework")              { continue }
      if check(.qt,        "QtCore.framework")             { continue }
      if check(.webkit,    "WebKit.framework")             { continue }

      // Catalyst: UIKit loaded from iOSSupport path
      // (handled separately in processExecutable to check full path)

      // Languages
      if check(.cplusplus, "libc++")                       { continue }
      if check(.objc,      "libobjc")                      { continue }
      if check(.swift,     "libswiftCore")                 { continue }
    }
  }
}
