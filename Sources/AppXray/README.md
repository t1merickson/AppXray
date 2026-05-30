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
    DetectedTechnologies.swift   OptionSet of 30 technology flags + display names + SF Symbol mappings
    ExecutableFileTechnologyInfo.swift   Aggregated results for a scanned bundle
    InfoDict.swift               Info.plist wrapper
    LoadBundleImage.swift        App icon loading

  Utilities/
    OTool.swift                  Runs llvm-objdump, parses linked libraries
    ProcessHelper.swift          Subprocess execution
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

`BundleFeatureDetectionOperation` runs on a background queue and reports state changes back to the main thread via a delegate protocol. The four detection phases run in order:

1. **Bundle structure** -- checks for known framework/resource paths on disk
2. **Info.plist** -- reads bundle metadata for SDK, scripting, and platform identifiers
3. **Dependency analysis** -- runs `llvm-objdump --macho --dylibs-used` on the main executable and recursively on embedded frameworks
4. **Binary strings** -- searches raw binary content when library analysis is ambiguous (e.g. Tauri binaries that statically link Rust)

Results accumulate in a `DetectedTechnologies` OptionSet (UInt64 bitmask, 30 flags). Each flag has a `displayName` and `symbolName` (SF Symbol) for the UI.


### Window state flow

Each main window owns a `WindowState` (ObservableObject) that drives `ContentView`:

```
.empty  -->  .loading(url)  -->  .app(info)
                             \-> .notAnApp(url)
```

`ContentView` switches between `PleaseDropAFileView`, a `ProgressView`, `MainFileView`, or `SorryNotAnExecutableView` based on the current state.


### Results UI

`MainFileView` shows a horizontal app header (icon + name + bundle filename), then groups detected technologies into sections (Frameworks, Languages, Runtimes). Each section is a rounded-rect card with individual `TechnologyRow` views showing an SF Symbol icon and technology name. A `SummaryView` at the bottom provides a one-line natural language description.

Technology grouping is defined by static arrays on `DetectedTechnologies` (`frameworkFlags`, `languageFlags`, `runtimeFlags`). The `items(in:)` method filters to only present flags and returns `TechnologyItem` structs for the view.


### About panel and license window

`InfoPanel` is a content-sized SwiftUI view (fixed width 340, height auto-sizes). The "Third-Party Licenses" button uses `NSApp.sendAction` through the responder chain to reach `AppDelegate.showLicenses(_:)`, which owns the license window as a lazy property.
