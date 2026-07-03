//
//  BundleFeatureDetectionOperation.swift
//  AppXray
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

  // Cancellation: set on the main thread (e.g. when the window closes or a new
  // file is loaded), read on the background worker between phases.
  private let cancelLock = NSLock()
  private var _isCancelled = false
  var isCancelled: Bool {
    cancelLock.lock(); defer { cancelLock.unlock() }
    return _isCancelled
  }
  func cancel() {
    cancelLock.lock(); _isCancelled = true; cancelLock.unlock()
  }

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

  /// Delivers @Published mutations to the main queue. Uses DispatchQueue.main
  /// (not RunLoop.main.perform) so updates are FIFO-ordered and not deferred
  /// during modal panels, menu tracking, or live window resizing.
  private func apply(_ block: @escaping () -> Void) {
    DispatchQueue.main.async(execute: block)
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

  /// The result of analyzing a directory as an app bundle.
  private enum WrapperResult {
    case ok(ExecutableFileTechnologyInfo)
    case notAnApp
    case failedToOpen
  }

  /// Runs the full pipeline on a background queue, accumulating into a local
  /// value, then publishes the result in a single main-thread hop. Keeping all
  /// intermediate state local avoids cross-thread reads of @Published members.
  private func startWork() {
    guard !isCancelled else { return }

    // Hold security-scoped access for the top-level dropped/opened URL so
    // sandboxed reads of the bundle succeed (nested children share it).
    let scoped = (nesting == 1) && url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    var isDir : ObjCBool = false
    guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
      return applyState(.failedToOpen(nil))
    }

    let result : ExecutableFileTechnologyInfo
    if isDir.boolValue {
      switch analyzeWrapper(url) {
        case .failedToOpen:     return applyState(.failedToOpen(nil))
        case .notAnApp:         return applyState(.notAnApplication)
        case .ok(let analyzed): result = analyzed
      }
    }
    else {
      guard fm.isExecutableFile(atPath: url.path) else {
        return applyState(.notAnApplication)
      }
      result = analyzeExecutableFile(url)
    }

    guard !isCancelled else { return }
    apply {
      self.info  = result
      self.state = .finished
    }
  }


  // MARK: - Workers

  /// Analyzes an app bundle entirely on the calling (background) thread and
  /// returns the populated info value. Used both for the top-level scan and,
  /// synchronously, for nested bundles.
  private func analyzeWrapper(_ url: URL) -> WrapperResult {
    guard let bundle = Bundle(url: url) else {
      print("could not open bundle:", url)
      return .failedToOpen
    }

    let infoDict = InfoDict(bundle.infoDictionary ?? [:])

    var result = ExecutableFileTechnologyInfo(fileURL: url)
    result.infoDictionary = infoDict
    result.receiptURL     = bundle.appStoreReceiptURL

    var detected = DetectedTechnologies()

    // Phase 1: Bundle structure scan (fast, no process spawning)
    detected.formUnion(processDirectoryContents(url))
    // Phase 2: Info.plist analysis
    detected.formUnion(processInfoDict(infoDict))
    // Platform type from plist + structure
    result.platformType = determinePlatform(info: infoDict, bundleURL: url)

    if let executableURL = bundle.executableURL {
      result.executableURL = executableURL
      result.appImage      = loadImage(in: infoDict, bundle: bundle)

      // Unreal Engine: shipping builds name the executable "<Game>-Mac-Shipping".
      let exeName = executableURL.lastPathComponent
      if exeName.hasSuffix("-Mac-Shipping") || exeName.hasSuffix("-Shipping") {
        detected.insert(.unreal)
        detected.insert(.cplusplus)
      }

      // Phase 3: Dependency analysis (objdump). Bail before this and the
      // binary scan if the work was cancelled (window closed / new file loaded).
      if !isCancelled {
        let dep = dependencyFeatures(executableURL)
        result.dependencies = dep.deps
        detected.formUnion(dep.features)
        if dep.features.contains(.catalyst) && result.platformType == .macOS {
          result.platformType = .catalyst
        }
        if nesting == 1 { apply(\.otoolAvailable, dep.otoolAvailable) }
      }

      // Phase 4: Binary string analysis (selective)
      if !isCancelled {
        detected.formUnion(binaryStringFeatures(executableURL, current: detected))
      }
    }
    else {
      // A bundle directory with no executable: show partial results for a real
      // (if malformed) .app; treat anything else as not an application.
      guard url.pathExtension == "app" else {
        print("no executable in bundle:", bundle)
        return .notAnApp
      }
      result.appImage = loadImage(in: infoDict, bundle: bundle)
    }

    result.detectedTechnologies = detected

    // Scan nested applications synchronously on this thread.
    if nesting < 2 {
      result.embeddedExecutables =
        scanNestedApplications(in: url, ownAppName: url.lastPathComponent)
    }

    return .ok(result)
  }

  /// Analyzes a bare (non-bundle) executable file.
  private func analyzeExecutableFile(_ url: URL) -> ExecutableFileTechnologyInfo {
    var result = ExecutableFileTechnologyInfo(fileURL: url)
    result.executableURL = url

    var detected = DetectedTechnologies()
    let dep = dependencyFeatures(url)
    result.dependencies = dep.deps
    detected.formUnion(dep.features)
    if nesting == 1 { apply(\.otoolAvailable, dep.otoolAvailable) }
    detected.formUnion(binaryStringFeatures(url, current: detected))

    result.detectedTechnologies = detected
    return result
  }


  // MARK: - Phase 1: Bundle Structure Scan

  /// Scans the bundle directory structure for framework and file markers.
  /// This is the fastest detection phase -- pure filesystem checks.
  func processDirectoryContents(_ url: URL) -> DetectedTechnologies {
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
      // Raw Chromium browsers ship the engine as "<Product> Framework.framework"
      // (distinct from Electron and CEF, which are matched above).
      if filename == "Google Chrome Framework.framework"
      || filename == "Chromium Framework.framework"
      || filename == "Brave Browser Framework.framework"
      || filename == "Microsoft Edge Framework.framework"
      || filename == "Vivaldi Framework.framework"
      || (filename.hasPrefix("Opera") && filename.hasSuffix(" Framework.framework")) {
        detected.insert(.chromium)
        continue
      }
      // Gecko: Firefox-family browsers ship the XUL runtime as a library.
      if filename == "libxul.dylib" || filename == "XUL.framework" {
        detected.insert(.gecko)
        continue
      }
      // Flutter
      if filename == "FlutterMacOS.framework" {
        detected.insert(.flutter)
        continue
      }
      // NW.js (node-webkit) -- distinct from Electron's framework name
      if filename == "nwjs Framework.framework" {
        detected.insert(.nwjs)
        detected.insert(.javascript)
        continue
      }
      // Qt across eras: Qt*.framework (Qt4-6) or any libQt* dylib
      // (libQtCore = Qt4, libQt5Core = Qt5, libQt6Core = Qt6). "libQt" is
      // Qt-specific, so the broad prefix is safe.
      if (filename.hasPrefix("Qt") && filename.hasSuffix(".framework"))
      || filename.hasPrefix("libQt") {
        detected.insert(.qt)
        continue
      }
      // Capacitor / Ionic
      if filename == "Capacitor.framework" || filename == "Cordova.framework" {
        detected.insert(.capacitor)
        detected.insert(.javascript)
        continue
      }
      // React Native -- exact frameworks plus case-insensitive Hermes / React*
      if filename == "React.framework"
      || filename == "React-Core.framework"
      || filename.hasPrefix("React")
      || filename.lowercased().hasPrefix("hermes") {
        detected.insert(.reactNative)
        detected.insert(.javascript)
        continue
      }
      // wxWidgets
      if filename.hasPrefix("libwx_") {
        detected.insert(.wxWidgets)
        continue
      }
      // GTK across eras: libgtk-/libgdk- covers GTK2 (libgtk-x11-2.0), GTK3,
      // and GTK4. Require an actual GTK/GDK library -- libglib-2.0 alone is NOT
      // a GTK signal (Qt, GStreamer, and others bundle GLib without using GTK).
      if filename.hasPrefix("libgtk-") || filename.hasPrefix("libgdk-") {
        detected.insert(.gtk)
        continue
      }
      // SDL
      if filename.hasPrefix("libSDL2") || filename.hasPrefix("libSDL3")
      || filename == "SDL2.framework" {
        detected.insert(.sdl)
        continue
      }
      // JavaFX (bundled native libs)
      if filename == "libglass.dylib" || filename.hasPrefix("libjavafx_")
      || filename.hasPrefix("libprism") {
        detected.insert(.javafx)
        detected.insert(.java)
        continue
      }
      // Sparkle updater (dominant non-MAS updater)
      if filename == "Sparkle.framework" {
        detected.insert(.sparkle)
        continue
      }
      // Squirrel.Mac updater (common with Electron)
      if filename == "Squirrel.framework" {
        detected.insert(.squirrel)
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
      // Unity (check before the generic Mono prefix below)
      if filename.hasPrefix("libmonobdwgc") || filename == "UnityPlayer.dylib"
      || filename == "libil2cpp.dylib" {
        detected.insert(.unity)
        continue
      }
      // Mono / Xamarin.Mac runtime dylibs
      if filename == "libmonosgen-2.0.dylib" || filename == "libMonoPosixHelper.dylib"
      || filename == "Mono.framework" || filename.hasPrefix("libmono") {
        detected.insert(.mono)
        detected.insert(.dotnet)
        continue
      }
    }

    // Managed .NET assemblies live in Frameworks, MonoBundle, or Resources
    // depending on the packaging (Avalonia / .NET MAUI).
    let managedDLLDirs = [
      frameworksURL,
      contents.appendingPathComponent("MonoBundle"),
      contents.appendingPathComponent("Resources"),
    ]
    for dir in managedDLLDirs {
      for filename in fm.ls(dir) {
        if filename == "Avalonia.dll" || filename == "Avalonia.Native.dll" {
          detected.insert(.avalonia)
          detected.insert(.dotnet)
        }
        if filename == "Microsoft.Maui.dll" || filename == "Microsoft.Maui.Controls.dll" {
          detected.insert(.dotnet)
        }
      }
    }

    // --- Qt in non-standard location (e.g. Ableton: Contents/Qt/lib/) ---
    if !detected.contains(.qt) {
      let qtLibURL = contents.appendingPathComponent("Qt/lib")
      for filename in fm.ls(qtLibURL) {
        if filename.hasPrefix("Qt") && filename.hasSuffix(".framework") {
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

    // Gecko: Firefox-family browsers (Firefox, Tor, LibreWolf, ...) ship the
    // XUL runtime in MacOS/ and packed resources as omni.ja.
    if fm.fileExists(atPath: contents.appendingPathComponent("MacOS/XUL").path)
    || fm.fileExists(atPath: resources.appendingPathComponent("omni.ja").path)
    || fm.fileExists(atPath: resources.appendingPathComponent("browser/omni.ja").path) {
      detected.insert(.gecko)
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

    // Java: Contents/Java or Contents/Eclipse (classic), or a bundled JRE from
    // jpackage/jlink (Contents/runtime/.../libjvm.dylib) or Contents/app jars.
    var hasJava = false
    for dir in [ "Java", "Eclipse" ] {
      if fm.fileExists(atPath: contents.appendingPathComponent(dir).path) {
        hasJava = true
        break
      }
    }
    if !hasJava,
       fm.fileExists(atPath: contents.appendingPathComponent(
         "runtime/Contents/Home/lib/libjvm.dylib").path) {
      hasJava = true
    }
    if !hasJava,
       !fm.ls(contents.appendingPathComponent("app"), suffix: ".jar").isEmpty {
      hasJava = true
    }
    if hasJava { detected.insert(.java) }

    // Mono/Xamarin: Contents/MonoBundle
    if fm.fileExists(atPath: contents.appendingPathComponent("MonoBundle").path) {
      detected.insert(.mono)
      detected.insert(.dotnet)
    }

    // Unreal Engine: shipping bundles carry a Contents/UE4 or Contents/UE5 payload
    for dir in [ "UE4", "UE5" ] {
      if fm.fileExists(atPath: contents.appendingPathComponent(dir).path) {
        detected.insert(.unreal)
        detected.insert(.cplusplus)
        break
      }
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
  func processInfoDict(_ info: InfoDict) -> DetectedTechnologies {
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
  func determinePlatform(info: InfoDict, bundleURL: URL) -> PlatformType {
    // iOS app on Mac (via Wrapper/)
    if fm.fileExists(atPath: bundleURL.appendingPathComponent("Wrapper").path) {
      return .iOS
    }
    // iOS app on Mac (via DTPlatformName)
    if info.platformName == "iphoneos" {
      return .iOS
    }
    // Catalyst hint: a macOS bundle that also carries iOS UIDeviceFamily +
    // MinimumOSVersion. (Real Catalyst apps usually also set
    // LSMinimumSystemVersion, so we do not require its absence.) The
    // iOSSupport dependency-path check in Phase 3 refines this.
    if !info.deviceFamily.isEmpty && info.minimumOSVersion != nil {
      return .catalyst
    }
    return .macOS
  }


  // MARK: - Phase 3: Dependency Analysis

  /// Runs objdump on the executable (traversing dependencies) and returns the
  /// resolved dependency list plus the features inferred from it. Pure: does
  /// not touch @Published state, so it is safe for nested/background use.
  private func dependencyFeatures(_ executableURL: URL)
    -> (deps: [String], features: DetectedTechnologies, otoolAvailable: Bool)
  {
    do {
      let dependencies = try otool(executableURL)

      var features = DetectedTechnologies()
      features.scanDependencies(dependencies)

      // Detect Catalyst from iOSSupport paths in dependencies
      for dep in dependencies where dep.contains("/System/iOSSupport/") {
        features.insert(.catalyst)
        break
      }

      return (dependencies, features, true)
    }
    catch {
      print("Could not invoke OTool:", error)
      return ([], DetectedTechnologies(), false)
    }
  }


  // MARK: - Phase 4: Binary String Analysis

  /// Bytes of the executable to scan for marker strings. Bounded so a multi-GB
  /// game/Electron binary is never read whole.
  private static let binaryScanLimit = 4_000_000

  /// Scans a bounded prefix of the executable for technology markers that have
  /// no reliable on-disk signal (Rust/Tauri, Go/Wails, Godot embedded-PCK,
  /// .NET single-file, Kotlin/Native, statically-linked Qt).
  ///
  /// Skipped when a definitive heavy framework is already known -- those stacks
  /// never coincide with the string-only ones, and skipping keeps the common
  /// Electron/Chromium/Unity case fast.
  func binaryStringFeatures(_ executableURL: URL,
                            current: DetectedTechnologies) -> DetectedTechnologies
  {
    let definitive: DetectedTechnologies = [
      .electron, .cef, .flutter, .unity, .unreal,
      .reactNative, .capacitor, .nwjs, .godot,
    ]
    guard current.intersection(definitive).isEmpty else { return [] }

    guard let data = readPrefix(of: executableURL,
                                maxBytes: Self.binaryScanLimit) else { return [] }
    let s = extractPrintableStrings(from: data)

    var detected = DetectedTechnologies()
    func has(_ needle: String) -> Bool { s.contains(needle) }
    func hasAny(_ needles: [String]) -> Bool { needles.contains { s.contains($0) } }

    // Tauri (Rust + native WebView)
    if hasAny(["tauri://", "__TAURI_METADATA__", "__TAURI_IPC__"]) {
      detected.insert(.tauri); detected.insert(.rust)
    }
    // Wails (Go + native WebView)
    if has("/wailsjs/") || has("wails.localhost") {
      detected.insert(.wails); detected.insert(.go)
    }
    // Rust (general)
    if !detected.contains(.rust),
       hasAny(["/.cargo/registry", "/rustc/", "RUST_BACKTRACE"]) {
      detected.insert(.rust)
    }
    // Go (general)
    if !detected.contains(.go),
       has("Go build ID:") || has("go.buildid") || has("runtime.goexit") {
      detected.insert(.go)
    }
    // Godot with the PCK embedded in the executable (the default export)
    if has("GDPC") && has("res://") {
      detected.insert(.godot)
    }
    // .NET self-contained single-file (runtime embedded in the AppHost)
    if has("DOTNET_BUNDLE_EXTRACT_BASE_DIR") || has("System.Private.CoreLib") {
      detected.insert(.dotnet)
    }
    // Kotlin/Native
    if has("kfun:") || has("Konan_") {
      detected.insert(.kotlin)
    }
    // Statically-linked Qt (no Qt frameworks present on disk)
    if !current.contains(.qt), has("qt_version_tag") || has("QObject::") {
      detected.insert(.qt)
    }

    return detected
  }

  /// Reads up to `maxBytes` from the start of a file without mapping or reading
  /// the whole thing into memory.
  private func readPrefix(of url: URL, maxBytes: Int) -> Data? {
    guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? fh.close() }
    let data = try? fh.read(upToCount: maxBytes)
    return data ?? nil
  }

  /// Extracts printable ASCII strings from binary data, similar to `strings(1)`.
  /// Indexes via `withUnsafeBytes`, so it is correct regardless of the Data's
  /// `startIndex` (e.g. if a slice is ever passed in).
  func extractPrintableStrings(from data: Data) -> String {
    var result = ""
    result.reserveCapacity(data.count / 4)

    var current = ""
    current.reserveCapacity(64)

    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      for byte in raw {
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
    }
    if current.count >= 4 {
      result.append(current)
    }

    return result
  }


  // MARK: - Nested Applications

  /// Scans Contents/MacOS and Contents/Frameworks for nested `.app` bundles and
  /// returns their analyzed info. Runs synchronously on the calling thread (the
  /// child operation's `analyzeWrapper` returns a value directly), so results
  /// are read after they are produced -- no cross-thread timing hazard.
  private func scanNestedApplications(in url: URL, ownAppName: String)
    -> [ExecutableFileTechnologyInfo]
  {
    let contents = url.appendingPathComponent("Contents")
    var found = [ExecutableFileTechnologyInfo]()

    func scan(_ directory: URL) {
      for name in fm.ls(directory, suffix: ".app") where name != ownAppName {
        let child = BundleFeatureDetectionOperation(
          directory.appendingPathComponent(name), nesting: nesting + 1)
        guard case .ok(let info) = child.analyzeWrapper(child.url) else { continue }
        if info.executableURL  != nil &&
           info.infoDictionary != nil &&
           !info.detectedTechnologies.isEmpty
        {
          found.append(info)
        }
      }
    }

    scan(contents.appendingPathComponent("MacOS"))
    scan(contents.appendingPathComponent("Frameworks"))
    return found
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
      if check(.qt,        "libQtCore")                    { continue } // Qt4
      if check(.qt,        "libQt5Core")                   { continue }
      if check(.qt,        "libQt6Core")                   { continue }
      if check(.webkit,    "WebKit.framework")             { continue }
      if check(.sdl,       "libSDL2")                       { continue }
      if check(.sdl,       "libSDL3")                       { continue }
      if check(.gtk,       "libgtk-")                       { continue }
      if check(.sparkle,   "Sparkle.framework")            { continue }
      if check(.squirrel,  "Squirrel.framework")           { continue }

      // Catalyst: UIKit loaded from iOSSupport path
      // (handled separately in dependencyFeatures to check the full path)

      // Languages
      if check(.cplusplus, "libc++")                       { continue }
      if check(.objc,      "libobjc")                      { continue }
      if check(.swift,     "libswiftCore")                 { continue }
    }
  }
}
