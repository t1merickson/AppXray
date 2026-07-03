# Plan 001: Establish an automated test baseline for the detection engine

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 57d746e..HEAD -- Sources/ AppXray.xcodeproj/project.pbxproj Tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (additive — new test target + visibility relaxations only; no behavior change)
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `57d746e`, 2026-07-03

## Why this matters

AppXray *is* its detection engine, and that engine churns constantly — 6 of the
last 10 commits changed detection signatures. Yet the project has **zero
automated tests**: a single app target, no test target, and every change is
verified by hand-scanning real apps. A real false positive already shipped this
way (GLib misread as GTK, fixed in commit `bf1fee0`). `Tests/expected_technologies.csv`
(427 apps of ground truth) exists but nothing consumes it. This plan creates a
unit-test target with fixture-based tests over the pure parts of the pipeline,
giving the repo its first one-command verification gate. Every later plan
(including the React Native false-positive fix in plan 002) builds on it.

## Current state

- `AppXray.xcodeproj` — single target `AppXray` (app), no test target, no shared
  scheme (schemes are auto-generated per-user). `xcodebuild -list` shows only
  target `AppXray` and scheme `AppXray`. Project settings that matter:
  `MACOSX_DEPLOYMENT_TARGET = 12.0`, `SWIFT_VERSION = 5.0`, `objectVersion = 54`.
- `Sources/AppXray/BundleFeatureDetectionOperation.swift` — the four-phase
  detection pipeline. The methods worth testing are `private`:
  - `private func processDirectoryContents(_ url: URL) -> DetectedTechnologies` (line 246) — Phase 1, pure filesystem checks against a bundle-root URL (it appends `Contents` itself).
  - `private func processInfoDict(_ info: InfoDict) -> DetectedTechnologies` (line 519) — Phase 2, pure.
  - `private func determinePlatform(info: InfoDict, bundleURL: URL) -> PlatformType` (line 556).
  - `private func binaryStringFeatures(_ executableURL: URL, current: DetectedTechnologies) -> DetectedTechnologies` (line 618) — Phase 4; reads a ≤4 MB prefix of the file at the URL; **skips itself entirely** when `current` already contains a "definitive" framework (see the `definitive` set at line 621).
  - `private func extractPrintableStrings(from data: Data) -> String` (line 685) — strings(1)-alike, minimum run length 4.
  - Constructing `BundleFeatureDetectionOperation(url)` has no side effects; work only starts on `resume()`. Safe to instantiate in tests.
- `Sources/AppXray/BundleFeatureDetectionOperation.swift:763-802` —
  `extension DetectedTechnologies { mutating func scanDependencies(_ dependencies: [String]) }`
  is already `internal` and pure. Testable as-is.
- `Sources/AppXray/Views/Windows/MainWindow/SummaryView.swift:136-228` — the
  one-line summary lives in `fileprivate extension ExecutableFileTechnologyInfo`
  as `var summaryText: String`, a priority cascade (Electron beats everything,
  then CEF/Chromium/Gecko, then Automator, Catalyst, iOS-on-Mac, Tauri/Wails/…,
  finally AppKit+Swift/ObjC, ending in a fallback string). The expected strings
  are in the `fileprivate struct Texts` in the same file.
- `Sources/AppXray/Model/InfoDict.swift` — plist wrapper; `init(_ dictionary: [String: Any])`
  is pure and already `internal`.
- Repo conventions: two-space indentation, aligned `:` in declarations is common
  but not required, comments explain *why* (see any file under `Sources/AppXray/`).
  No emoji in code.
- **Design constraint you must honor** (from `Sources/AppXray/README.md`,
  "Detection signatures are versioned (era-aware)"): *"Detection is additive,
  never exclusive. The absence of a newer marker must not be read as
  'technology not present'… Flags are only ever `insert`ed; one surface matching
  is enough."* Tests must assert that flags ARE set for each marker era — never
  assert a flag is absent merely because a *different* era's marker is missing.
  Asserting absence is correct only for genuine negative cases (e.g. GLib alone
  must not mean GTK).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build app | `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` | `** BUILD SUCCEEDED **` |
| List targets/schemes | `xcodebuild -list` | shows `AppXrayTests` after step 2 |
| Run tests | `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` | `** TEST SUCCEEDED **` |

Prerequisite (already satisfied on this machine): `LLVM/llvm-objdump` must exist
for the app target's "Bundle Objdump" copy phase. If it is missing, copy it:
`cp "$(xcrun --find llvm-objdump)" LLVM/llvm-objdump`.

## Scope

**In scope** (the only files you should modify/create):
- `AppXray.xcodeproj/project.pbxproj` (add test target)
- `AppXray.xcodeproj/xcshareddata/xcschemes/AppXrayTests.xcscheme` (create)
- `Tests/AppXrayTests/` (create; all new test sources live here)
- `Sources/AppXray/BundleFeatureDetectionOperation.swift` (visibility keywords only)
- `Sources/AppXray/Views/Windows/MainWindow/SummaryView.swift` (visibility keyword only)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- Any detection *logic* — no signature changes, no bug fixes, even ones the tests
  reveal as tempting (e.g. the `hasPrefix("React")` over-match — that is plan 002).
- `Tests/expected_technologies.csv` — reference data; a CSV-driven integration
  harness is explicitly deferred (see Maintenance notes).
- `OTool.swift` / `ProcessHelper.swift` behavior — subprocess code is not under
  test in this plan (it needs real Mach-O binaries; deferred).
- The existing `AppXray` scheme and all app-target build settings.

## Git workflow

- Branch: `advisor/001-detection-test-baseline`
- Commit style: imperative, concise subject line (match `git log --oneline`,
  e.g. "Detect Chromium and Gecko browser engines"). One commit for the target
  scaffolding, one for the tests is fine.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Relax visibility on the methods under test

In `Sources/AppXray/BundleFeatureDetectionOperation.swift`, change `private func`
to `func` (internal) for exactly these five members:
`processDirectoryContents`, `processInfoDict`, `determinePlatform`,
`binaryStringFeatures`, `extractPrintableStrings`.
Do NOT change `startWork`, `analyzeWrapper`, `apply`, or the cancellation members.

In `Sources/AppXray/Views/Windows/MainWindow/SummaryView.swift`, change
`fileprivate extension ExecutableFileTechnologyInfo` (line 138) to
`extension ExecutableFileTechnologyInfo`. Leave `fileprivate struct Texts`
as-is — it is same-file accessible from the extension, and tests will assert
against hardcoded literal strings instead.

**Verify**: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` → `** BUILD SUCCEEDED **`

### Step 2: Add the `AppXrayTests` unit-test target to the project

Edit `AppXray.xcodeproj/project.pbxproj` by hand. Design decisions (do not
deviate): a **unit-test bundle with no test host** (`TEST_HOST` unset) that
**compiles the needed app sources directly into the test bundle**. This avoids
app-sandbox and `@testable`/host-app complications entirely.

The test target's Sources build phase must compile:
1. These 8 existing app sources (find each file's existing `PBXFileReference`
   UUID by grepping the pbxproj for its filename, then add a new `PBXBuildFile`
   entry per file for the test target):
   - `BundleFeatureDetectionOperation.swift`
   - `Model/DetectedTechnologies.swift`
   - `Model/ExecutableFileTechnologyInfo.swift`
   - `Model/InfoDict.swift`
   - `Model/LoadBundleImage.swift`
   - `Utilities/OTool.swift`
   - `Utilities/ProcessHelper.swift`
   - `Views/Windows/MainWindow/SummaryView.swift`
   (These are the transitive compile-time closure: the operation references
   `loadImage`, `otool`, `InfoDict`, the model types; `OTool` references
   `Process.launch`. If the build errors on an unresolved symbol from another
   file, add that one file too and note it in your report.)
2. The new test files from step 3 (add `PBXFileReference` + `PBXBuildFile`
   entries and a `Tests/AppXrayTests` group).

Required pbxproj additions (generate fresh unique 24-hex-digit UUIDs for each
new object; the convention in this file is uppercase hex):
- One `PBXFileReference` — `AppXrayTests.xctest`, `explicitFileType = wrapper.cfbundle; includeInIndex = 0; sourceTree = BUILT_PRODUCTS_DIR;`.
- One `PBXNativeTarget` — name `AppXrayTests`,
  `productType = "com.apple.product-type.bundle.unit-test"`, with a Sources
  phase and a Frameworks phase (Frameworks phase may be empty), no dependency
  on the app target.
- One `XCConfigurationList` with Debug/Release `XCBuildConfiguration`s. Build
  settings for both configurations:
  ```
  BUNDLE_LOADER = "";
  CODE_SIGN_STYLE = Automatic;
  CURRENT_PROJECT_VERSION = 1;
  GENERATE_INFOPLIST_FILE = YES;
  MACOSX_DEPLOYMENT_TARGET = 12.0;
  PRODUCT_BUNDLE_IDENTIFIER = "com.timerickson.appxray.tests";
  PRODUCT_NAME = "$(TARGET_NAME)";
  SWIFT_VERSION = 5.0;
  ```
- Register the target in the `PBXProject` object's `targets` list and add the
  product to the Products group.

**Verify**: `xcodebuild -list` → `Targets:` now includes `AppXrayTests`.

### Step 3: Write the tests

Create `Tests/AppXrayTests/` with the following files. All tests use XCTest
(`import XCTest`; the app sources are compiled into the same module, so no
`@testable import` — there is no module to import).

**`BundleFixture.swift`** — the shared fixture builder:

```swift
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
  func touch(_ relativePath: String, contents: Data = Data()) throws -> URL { … }

  /// Creates a directory at a bundle-root-relative path.
  @discardableResult
  func mkdir(_ relativePath: String) throws -> URL { … }

  func destroy() { try? FileManager.default.removeItem(
    at: root.deletingLastPathComponent()) }
}
```

Note: framework "directories" can be created with `touch` as plain empty
*files* named e.g. `Contents/Frameworks/Electron Framework.framework` — Phase 1
only lists filenames (`fm.ls`), it never descends into frameworks. Use `mkdir`
where the detector checks `fileExists` on a directory (`Contents/UE5`,
`Contents/MonoBundle`, `Wrapper`).

**`DirectoryScanTests.swift`** — Phase 1. For each case: build fixture, run
`BundleFeatureDetectionOperation(fixture.root).processDirectoryContents(fixture.root)`,
assert flags, `destroy()` in `tearDown`. Cases (assert the listed flags are
present; where noted, assert absence):

| Fixture | Expect |
|---|---|
| `Contents/Frameworks/Electron Framework.framework` | `.electron`, `.javascript` |
| `Contents/Resources/app.asar` | `.electron`, `.javascript` |
| `Contents/Frameworks/Chromium Embedded Framework.framework` | `.cef` |
| `Contents/Frameworks/Google Chrome Framework.framework` | `.chromium` |
| `Contents/Frameworks/libxul.dylib` | `.gecko` |
| `Contents/Resources/omni.ja` | `.gecko` |
| `Contents/Frameworks/QtCore.framework` | `.qt` (Qt4-era surface) |
| `Contents/Frameworks/libQt6Core.6.dylib` | `.qt` (Qt6-era surface) |
| `Contents/Qt/lib/QtWidgets.framework` | `.qt` (non-standard location) |
| `Contents/Frameworks/libgtk-3.0.dylib` | `.gtk` |
| `Contents/Frameworks/libglib-2.0.dylib` | NOT `.gtk` (regression guard for commit `bf1fee0`) |
| `Contents/Frameworks/React.framework` | `.reactNative`, `.javascript` |
| `Contents/Frameworks/Hermes.framework` | `.reactNative` (case-insensitive hermes) |
| `Contents/Frameworks/Sparkle.framework` | `.sparkle` |
| `Contents/Resources/Data/globalgamemanagers` | `.unity` |
| `Contents/Resources/game.pck` | `.godot` |
| `Contents/UE5/` (dir) | `.unreal`, `.cplusplus` |
| `Contents/MonoBundle/` (dir) | `.mono`, `.dotnet` |
| `Contents/Frameworks/libcoreclr.dylib` | `.dotnet` |
| `Contents/Resources/Avalonia.dll` | `.avalonia`, `.dotnet` |
| `Contents/Java/` (dir) | `.java` |
| `Contents/runtime/Contents/Home/lib/libjvm.dylib` | `.java` (jpackage era) |
| `Contents/app/tool.jar` | `.java` |
| `Contents/Resources/Scripts/main.scpt` | `.applescript` |
| `Contents/Resources/AppSettings.plist` + `Contents/Resources/script` | `.platypus` |
| `Wrapper/` (dir, at bundle root) | `.iOSOnMac`, `.uikit` |
| empty bundle | empty set |

**`InfoDictTests.swift`** — Phase 2 + wrapper parsing:
- `InfoDict(["ElectronAsarIntegrity": ["x": 1]])` → `processInfoDict` yields `.electron`, `.javascript`.
- `["DTPlatformName": "iphoneos"]` → `.iOSOnMac`, `.uikit`; and `determinePlatform` → `.iOS`.
- `["AMIsApplet": true]` → `.automator`; `["LSRequiresCarbon": 1]` → `.carbon`; `["JavaX": [:]]` → `.java`.
- `determinePlatform` with `["UIDeviceFamily": [2], "MinimumOSVersion": "14.0"]` → `.catalyst`; with `[:]` → `.macOS`.
- Do NOT write assertions for string-typed `"0"`/`"1"` boolean plist values —
  that behavior is a known open question (see plans/README.md rejected/deferred
  list) and must not be locked in either direction here.

**`DependencyScanTests.swift`** — pure `scanDependencies` on `[String]` inputs:
`libswiftCore` → `.swift`; `libobjc` → `.objc`; `libc++` → `.cplusplus`;
`AppKit.framework` → `.appkit`; `SwiftUI.framework` → `.swiftui`;
`libQt5Core` → `.qt`; `Sparkle.framework` → `.sparkle`; a realistic multi-line
list sets the union; empty list → empty set.

**`BinaryStringTests.swift`** — write a `Data` containing marker bytes separated
by `\0` to a temp file, call `binaryStringFeatures(url, current: [])`:
- `RUST_BACKTRACE` → `.rust`; `Go build ID:` → `.go`; `GDPC` + `res://` → `.godot`
  (and `GDPC` alone → NOT `.godot`); `tauri://` → `.tauri` + `.rust`;
  `DOTNET_BUNDLE_EXTRACT_BASE_DIR` → `.dotnet`; `kfun:` → `.kotlin`;
  `qt_version_tag` → `.qt`.
- Skip gate: same file, `current: [.electron]` → returns `[]`.
- `extractPrintableStrings`: `"abc\0abcd\0"` bytes → output contains `abcd`,
  not a bare `abc` line (minimum run length 4).

**`SummaryTextTests.swift`** — build `ExecutableFileTechnologyInfo(fileURL:)`
values, set `detectedTechnologies`, assert `summaryText` against hardcoded
literals from `SummaryView.swift`'s `Texts`:
- `[]` → `"No technologies detected."`
- `[.electron, .swiftui]` → `"Uses Electron alongside SwiftUI."` (priority: electron branch wins)
- `[.appkit, .swift]` → `"An AppKit app written in Swift."`; `[.appkit, .objc]` → ObjC variant.
- `[.qt, .python]` → `"A Qt app written in Python."`
- embedded technologies count: an info with empty own flags but one
  `embeddedExecutables` entry carrying `.electron` → electron summary
  (exercises `allTechnologies`).

**Verify**: `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests`
(after step 4 creates the scheme; if running mid-step, `xcodebuild build -target AppXrayTests` at minimum must compile).

### Step 4: Create the shared test scheme

Create `AppXray.xcodeproj/xcshareddata/xcschemes/AppXrayTests.xcscheme`. Use
this XML, substituting `TESTTARGETUUID` with the `PBXNativeTarget` UUID you
generated for `AppXrayTests` in step 2:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
  <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO"
                        buildForProfiling = "NO" buildForArchiving = "NO"
                        buildForAnalyzing = "YES">
        <BuildableReference BuildableState = "buildable"
          BlueprintIdentifier = "TESTTARGETUUID"
          BuildableName = "AppXrayTests.xctest"
          BlueprintName = "AppXrayTests"
          ReferencedContainer = "container:AppXray.xcodeproj">
        </BuildableReference>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES">
    <Testables>
      <TestableReference skipped = "NO">
        <BuildableReference BuildableState = "buildable"
          BlueprintIdentifier = "TESTTARGETUUID"
          BuildableName = "AppXrayTests.xctest"
          BlueprintName = "AppXrayTests"
          ReferencedContainer = "container:AppXray.xcodeproj">
        </BuildableReference>
      </TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration = "Debug"
                selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
                selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
                launchStyle = "0" useCustomWorkingDirectory = "NO"
                ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES"
                debugServiceExtension = "internal" allowLocationSimulation = "YES">
  </LaunchAction>
</Scheme>
```

**Verify**: `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` → `** TEST SUCCEEDED **`, and the log shows all suites executed with 0 failures.

## Test plan

This plan *is* the test plan; the cases are enumerated in step 3. Coverage
targets: Phase 1 (28 fixture cases incl. 2 negative regression guards),
Phase 2 (6 cases), dependency matching (8), binary strings (9 incl. the skip
gate), summary cascade (5). ≥ 50 assertions total.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` → `** BUILD SUCCEEDED **` (app unaffected)
- [ ] `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` → `** TEST SUCCEEDED **` with ≥ 40 tests executed, 0 failures
- [ ] `git diff --stat` touches only: `project.pbxproj`, the new `.xcscheme`, `Tests/AppXrayTests/*`, the two source files from step 1, `plans/README.md`
- [ ] The step-1 diff to the two source files contains only visibility-keyword changes (`git diff Sources/` shows no logic edits)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The code at the locations in "Current state" doesn't match the excerpts.
- The test bundle fails to link because compiled app sources pull in more than
  2 additional files beyond the 8 listed — the compile-closure assumption is
  wrong; report which symbols.
- `xcodebuild test` cannot run the bundle at all (e.g. signing/loading errors
  that persist after one retry with `CODE_SIGNING_ALLOWED=NO` added) — do not
  start restructuring the project to work around it.
- Any test failure that looks like a *detection logic bug* rather than a wrong
  test expectation (e.g. `ReactiveCocoa.framework` matching `.reactNative` —
  that one is expected and is fixed by plan 002; do not add it as a test here,
  and do not fix the matcher).

## Maintenance notes

- **Adding a technology?** Add its fixture case(s) to `DirectoryScanTests`
  (one per detection era/surface — see the era-aware section of
  `Sources/AppXray/README.md`).
- Plan 002 depends on this target and adds the Reactive* negative cases.
- Plan 005 (CI) runs this scheme on every push.
- **Deferred, deliberately**: a harness that diffs live scans of locally
  installed apps against `Tests/expected_technologies.csv`. It's valuable but
  environment-dependent (requires those apps installed); revisit once the
  bulk-scan direction finding (plans/README.md) is decided.
- Reviewer focus: the step-1 visibility diff (must be keyword-only), and that
  fixture cases assert *presence* per era rather than absence (the era-aware rule).
