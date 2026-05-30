# AppXray Sources

Architecture guide for the AppXray codebase.

The app uses an AppKit lifecycle: `AppDelegate` creates windows with `NSWindow`/`NSHostingView`, and a storyboard (`Main.storyboard`) provides the menu bar. All views are SwiftUI, targeting macOS 12+.


### Directory layout

```
Sources/AppXray/
  AppDelegate.swift              App lifecycle, window management, menu actions
  WindowState.swift              Per-window state machine (empty/loading/notAnApp/app)
  Windows.swift                  NSWindow factory functions
  BundleFeatureDetectionOperation.swift   Four-phase detection pipeline

  Model/
    DetectedTechnologies.swift   OptionSet of 42 technology flags + display names + SF Symbol mappings + category groupings
    ExecutableFileTechnologyInfo.swift   Aggregated results for a scanned bundle
    InfoDict.swift               Info.plist wrapper
    LoadBundleImage.swift        App icon loading

  Utilities/
    OTool.swift                  Runs llvm-objdump, parses linked libraries, walks transitive deps
    ProcessHelper.swift          Subprocess execution (no-shell default, timeout watchdog)
    URLItems.swift               Drag-and-drop URL extraction (UTType)
    WindowEnvironmentKey.swift   SwiftUI environment key for the hosting NSWindow

  Views/
    ContentView.swift            Root view: drag-drop target + state routing
    Reusable/
      PropertiesView.swift       Key-value list used in the details popover
    Windows/
      InfoPanel/
        InfoPanel.swift          About panel (version, description, license link)
      LicenseWindow/
        ThirdPartyLicensesView.swift
      MainWindow/
        MainFileView.swift       Results screen: app header + technology sections + summary
        PleaseDropAFileView.swift   Empty state with dashed drop zone
        SorryNotAnExecutableView.swift   Error state for non-app files
        SummaryView.swift        One-line natural language summary of results
        DetailsPopover.swift     Bundle info + dependency list popover
```


### Detection engine

`BundleFeatureDetectionOperation` is an `ObservableObject` that runs on a background queue and reports state changes back to the main thread via a delegate protocol. The whole scan accumulates into a **local** `DetectedTechnologies` value and is published to the UI in a single main-thread hop, so the window never flickers through partial states and there are no cross-thread reads of `@Published` members.

The four detection phases run in order, fastest first:

1. **Bundle structure** (`processDirectoryContents`) — pure filesystem checks for framework/resource markers on disk. Scans `Contents/Frameworks` for named frameworks and dylibs (Electron, CEF, Flutter, NW.js, Qt, wxWidgets, GTK, SDL, JavaFX, Sparkle, Squirrel, Python, Avalonia/.NET, Unity, Mono…), then checks `Resources` and other content directories for app-specific markers: `app.asar` / `app/package.json` (Electron), `capacitor.config.json`, `Data/globalgamemanagers` (Unity), `*.pck` (Godot), `Resources/Scripts/*.scpt` (AppleScript), `Contents/MonoBundle`, `Contents/UE4`/`UE5` (Unreal), `Contents/Java`/`Eclipse` and bundled JREs (`runtime/.../libjvm.dylib`, `app/*.jar`), Platypus `AppSettings.plist` + `script`, and a top-level `Wrapper/` (iOS-on-Mac). It also handles Qt in non-standard locations (`Contents/Qt/lib`) and scans for managed .NET assemblies across `Frameworks`, `MonoBundle`, and `Resources`.

2. **Info.plist** (`processInfoDict`) — reads parsed bundle metadata: the Electron ASAR-integrity key, `DTPlatformName == iphoneos` (iOS-on-Mac), Automator-applet and Carbon flags, and Java markers. `determinePlatform` additionally classifies the bundle as macOS / Catalyst / iOS from plist + structure.

3. **Dependency analysis** (`dependencyFeatures` → `OTool`) — runs `llvm-objdump --macho --dylibs-used` on the main executable and recursively on its dependencies, deduplicating via a `scanned` set so shared subtrees aren't re-walked. The resulting dylib list is matched against known libraries (`libswiftCore`, `libobjc`, `libc++`, `AppKit.framework`, `SwiftUI.framework`, `QtCore`, `libSDL2/3`, `libgtk-`, `Sparkle.framework`, `Squirrel.framework`, …) in `scanDependencies`. Catalyst is confirmed when UIKit loads from a `/System/iOSSupport/` path.

4. **Binary strings** (`binaryStringFeatures`) — a selective last resort for stacks with no reliable on-disk signal: Tauri/Rust (`tauri://`, `__TAURI_IPC__`), Wails/Go (`/wailsjs/`, Go build-ID), general Rust (`/.cargo/registry`, `RUST_BACKTRACE`) and Go (`runtime.goexit`), Kotlin/Native (`kfun:`, `Konan_`), embedded-PCK Godot (`GDPC` + `res://`), .NET single-file AppHosts (`DOTNET_BUNDLE_EXTRACT_BASE_DIR`, `System.Private.CoreLib`), and statically-linked Qt (`qt_version_tag`, `QObject::`). To stay fast, it reads only a **bounded prefix** (`binaryScanLimit`, 4 MB) of the executable and is **skipped entirely** when a definitive heavy framework (Electron, CEF, Flutter, Unity, Unreal, React Native, Capacitor, NW.js, Godot) is already known — those stacks never coincide with the string-only ones.

Supporting behavior:

- **Nested apps** — `scanNestedApplications` recurses (one level) into `Contents/MacOS` and `Contents/Frameworks`, analyzing embedded `.app` bundles synchronously and attaching their results to `embeddedExecutables`.
- **Cancellation** — an `NSLock`-guarded flag, set on the main thread (window closed / new file dropped) and checked between phases on the worker, so an abandoned scan stops promptly.
- **Security-scoped access** — the top-level dropped URL is wrapped in `startAccessingSecurityScopedResource()` (released via `defer`) so sandboxed bundle reads succeed; nested children share that access.
- **Bare executables** — non-bundle Mach-O files go through `analyzeExecutableFile` (dependency + binary-string phases only).

Results accumulate in a `DetectedTechnologies` OptionSet (a `UInt64` bitmask, 42 flags). Each flag has a `displayName` and a `symbolName` (SF Symbol) for the UI.


### Window state flow

Each main window owns a `WindowState` (`ObservableObject`) that drives `ContentView`:

```
.empty  -->  .loading(url)  -->  .app(info)
                             \-> .notAnApp(url)
```

`ContentView` switches between `PleaseDropAFileView`, a `ProgressView`, `MainFileView`, or `SorryNotAnExecutableView` based on the current state. `ContentView` holds its `WindowState` as a `@StateObject`; loading a new URL cancels any in-flight detection, and the state is torn down on `deinit`.


### Results UI

`MainFileView` shows a horizontal app header (icon + name + bundle filename), then groups detected technologies into sections — **Frameworks**, **Languages**, **Runtimes**, and **Distribution** — followed by a list of any embedded/nested apps. Each section is a rounded-rect card with individual `TechnologyRow` views showing an SF Symbol icon and technology name. A `SummaryView` at the bottom provides a one-line natural language description.

Technology grouping is defined by static arrays on `DetectedTechnologies` (`frameworkFlags`, `languageFlags`, `runtimeFlags`, `distributionFlags`). The `items(in:)` method filters to only the present flags and returns `TechnologyItem` structs for the view; `names(in:)` returns just the display-name strings.


### About panel and license window

`InfoPanel` is a content-sized SwiftUI view (fixed width 340, height auto-sizes). The "Third-Party Licenses" button uses `NSApp.sendAction` through the responder chain to reach `AppDelegate.showLicenses(_:)`, which owns the license window as a lazy property. The panel retains the "Based on 5 GUIs by ZeeZide GmbH" attribution required by the upstream Apache 2.0 license.
