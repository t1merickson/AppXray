# AppXray Audit

> **Status — all confirmed and disputed findings addressed.** The fixes landed
> across `ProcessHelper.swift`, `OTool.swift`, `BundleFeatureDetectionOperation.swift`,
> `DetectedTechnologies.swift`, `WindowState.swift`, `ContentView.swift`,
> `Windows.swift`, `URLItems.swift`, `MainFileView.swift`, and `SummaryView.swift`.
> Build succeeds and the app launches cleanly. Highlights:
>
> - **Crashes/robustness:** About panel no longer released on close; objdump runs
>   under a timeout watchdog; missing objdump throws `objdumpMissing` (no more
>   `NSException`); `ProcessHelper` defaults to a no-shell argv exec and quotes
>   args when a shell is used; pipes are drained to EOF concurrently (no deadlock
>   / truncation). Also fixed a latent force-unwrap of the app icon.
> - **Concurrency:** detection now accumulates in a background-local value and
>   publishes once via `DispatchQueue.main.async`; the cross-thread semaphore read
>   and the nested read-before-async bug are gone; in-flight scans are cancellable
>   (window close / reload); `ContentView` uses `@StateObject`.
> - **Coverage:** new flags **Go, Kotlin, Wails, GTK, SDL, NW.js, JavaFX, Sparkle,
>   Squirrel** (+ a Distribution UI section); Unreal is now actually detected;
>   Godot embedded-PCK, .NET single-file, static Qt, Tauri/Rust, and Go/Wails via
>   bounded binary-string scan; broadened Qt and React Native matching; Mono dylibs,
>   modern Java (jpackage), and managed-DLL scanning beyond `Frameworks/`.
> - **Two items addressed via alternatives (noted inline):** the objdump `--rpaths`
>   second pass → covered by static-toolkit string markers instead; the sandbox
>   "partial scan" UI state → added security-scoped resource access (the concrete
>   fix), without a new UI state.
>
> Original findings preserved below for reference.

A multi-agent audit of the detection pipeline and app lifecycle. Six review
dimensions (detection logic, subprocess/objdump robustness, concurrency,
edge cases, UI/lifecycle, detection coverage) fanned out over the source, and
every finding was adversarially verified by two independent reviewers (a
correctness lens and an impact lens).

**Result:** 56 raw findings → **33 confirmed** (both verifiers agreed), 9 disputed
(one verifier dissented), 14 rejected. Rejected findings are dropped; disputed
ones are listed at the end for a second look.

File/line references are against the current tree.

---

## High severity

### 1. About panel crashes on reopen (use-after-free)
`AppDelegate.swift:40-45`, `Windows.swift:54-73` — `infoPanel` is a `lazy var`
holding a plain `NSWindow`. `NSWindow.isReleasedWhenClosed` defaults to `true`,
so closing the About window releases the object; the stored property dangles and
the next "About AppXray" call messages a freed window. `makeLicenseWindow`
already sets `isReleasedWhenClosed = false` — `makeInfoPanel` does not.
**Fix:** set `window.isReleasedWhenClosed = false` in `makeInfoPanel`.

### 2. A hung `objdump` hangs detection forever
`ProcessHelper.swift:65-66` — `launch()` then `waitUntilExit()` with no timeout.
A malformed/truncated Mach-O or pathological dependency graph that makes
`llvm-objdump` block never returns, and since `otool()` drives a recursive
transitive walk, one hang stalls all of Phase 3 with no recovery.
**Fix:** add a deadline (terminate + SIGKILL after grace) via a timeout work
item or `terminationHandler` + `semaphore.wait(timeout:)`; treat timeout as failure.

### 3. Missing-objdump fallback throws an uncatchable `NSException`
`OTool.swift:33-37` — when the embedded `llvm-objdump` is absent/unsigned, the
code falls back to a hard-coded Xcode path **without checking it exists**, then
passes it to the legacy `process.launch()`. On a machine with no Xcode (the
common end-user case) this raises an Objective-C `NSException` that Swift `do/catch`
cannot catch → crash.
**Fix:** guard the fallback with `isExecutableFile(atPath:)` and throw
`objdumpMissing`; prefer `process.run()` so failures surface as Swift errors.
Relatedly, the fallback path itself is version-fragile (`OTool.swift:33-34`) — it breaks
for Xcode-beta, CLT-only, or relocated Xcode. Treat the embedded tool as the only
supported one and degrade cleanly (`otoolAvailable = false`).

### 4. Default shell mode joins args unquoted (`/bin/bash -c`)
`ProcessHelper.swift:33-39` — `launch()` defaults to `shell = "/bin/bash"` and
builds `["-c", launchPath + " " + arguments.joined(separator: " ")]` with no
quoting. Any path with a space (ubiquitous) or shell metacharacter (`$ ; & * ( )`
backtick — all legal in macOS bundle names) is mis-parsed or injected. The live
`otool` path is safe because it passes `using: .none`, so this is a latent
footgun in the API default rather than an active exploit today.
**Fix:** make the no-shell (argv array) path the default; if a shell is ever
needed, single-quote each argument.

### 5. Nested-app results read before the async mutations land
`BundleFeatureDetectionOperation.swift:556-567` — `processNestedApplications`
calls the child `op.startWork()` synchronously on the background queue, then
immediately reads `op.info.executableURL / infoDictionary / detectedTechnologies`.
But `startWork` mutates `op.info` only through `apply { … }` → `RunLoop.main.perform`,
which has **not run yet** at the read point, so the nested-app gate almost always
sees empty values and embedded executables are dropped.
**Fix:** give the operation a synchronous nested path that mutates and returns a
plain local `ExecutableFileTechnologyInfo`, instead of routing through the
main-runloop indirection.

### 6. Unreal Engine is wired up everywhere but never detected
`DetectedTechnologies.swift:47` + pipeline — `.unreal` has a display name, symbol,
category grouping, a `SummaryView` branch, and a slot in the Phase-4
`majorFrameworks` gate, but **no phase ever inserts it** (no marker in
`processDirectoryContents`, `processInfoDict`, `scanDependencies`, or
`processBinaryStrings`). Every Unreal game reports as undetected; the
`SummaryView` branch is unreachable.
**Fix:** insert `.unreal` (+ `.cplusplus`) from a real marker — e.g. a
`Contents/UE4`/`UE5` directory, a `*-Mac-Shipping` executable, or `*.pak` under
`Content/Paks`.

---

## Detection coverage gaps (confirmed)

The audit's richest vein. These are missing/weak detections, each with a concrete,
implementable marker.

| Tech | Problem | Suggested marker |
|------|---------|------------------|
| **Unreal** | flag declared, never set (see #6) | `Contents/UE4`/`UE5` dir, `*-Mac-Shipping`, `*.pak` |
| **Godot** | only standalone `.pck` in `Resources/`; embedded-PCK (the default export) missed | binary markers `GDPC` + `res://`; `libgodot.macos.*` |
| **Mono** | only `Contents/MonoBundle`; misses dylib markers | `libmonosgen-2.0.dylib`, `libMonoPosixHelper.dylib`, `Mono.framework` |
| **.NET single-file / MAUI** | self-contained AppHost has no runtime dylib on disk | binary `DOTNET_BUNDLE_EXTRACT_BASE_DIR`, `System.Private.CoreLib` |
| **Avalonia/MAUI .dll** | scans only flat `Frameworks/`; managed DLLs live in `MonoBundle`/`Resources` | scan `MonoBundle`/`Resources` for the `.dll` names |
| **Tauri / Rust** | gated behind WebKit; pure-Rust & mis-gated Tauri never scanned | decouple: always scan for `/.cargo/registry`, `/rustc/` |
| **Go** | no flag at all | binary `Go buildinf:` / `go.buildid`, `runtime.` symbols |
| **Wails** | Go+WebView, matches no marker → looks like bare WebKit | binary `wails` / `/wailsjs/` + Go marker |
| **GTK / SDL** | no flags | `libgtk-3/4`, `libgdk-3`, `libglib-2.0`; `libSDL2/3`, `SDL2.framework` |
| **React Native** | only exact `React.framework`/`hermes.framework`; misses static-linked & case variants | case-insensitive `hermes`, prefix `React`, string fallback `RCTBridge`/`facebook::react` |
| **NW.js** | ships `nwjs Framework.framework`, not Electron's | match `nwjs Framework.framework` + `Resources/package.nw` |
| **Qt** | only `QtCore*`/`QtGui*` names; misses Qt6/QtWidgets-only/static | broaden to any `Qt*.framework`/`libQt5*`/`libQt6*`; static string `qt_version_tag` |
| **JavaFX / modern Java** | only `Contents/Java`/`Eclipse` dir; misses jpackage/jlink | `Contents/runtime/.../libjvm.dylib`, `Contents/app/*.jar`; JavaFX `libglass.dylib`/`libjavafx_*` |
| **Kotlin/Native** | no flag | binary `kfun:`/`Konan`; Compose desktop ships `libskiko-macos-*` |
| **Sparkle / Squirrel** | updater frameworks not surfaced as distribution signals | `Sparkle.framework`; `Squirrel.framework`/`ShipIt` |

**Tooling improvement** (`OTool.swift:112-115`): `objdump` is invoked with only
`--macho --dylibs-used`, so statically-linked toolkits (Qt/Go/Rust/Kotlin-Native)
with few dynamic deps fall through. A second `--macho --rpaths` /
`LC_BUILD_VERSION` pass would recover rpath hints and the build platform
(macOS vs iOS-sim vs Catalyst) — see also the disputed Catalyst heuristic below.

> Real-world confirmation from the CSV pass: **launcher-stub apps** (Firefox, Chrome,
> Safari, Zen, Helium, LibreOffice) expose almost nothing via `otool -L` on the main
> binary — their engines live in `Contents/Frameworks` under app-specific names
> (`Google Chrome Framework.framework`, `Helium Framework.framework`, Gecko's
> `XUL`/`omni.ja`). AppXray detects none of these. A Frameworks-name heuristic for
> the major browser engines would close a visible gap.

---

## Correctness & robustness (confirmed, medium/low)

- **Nested-app filter is a no-op** (`BundleFeatureDetectionOperation.swift:170-171,
  548-556`): called with the CFBundleExecutable name (e.g. `Slack`) but filters a
  `.app` listing (`Slack Helper.app`) with `{ $0 != ownExecutable }` — a `.app`
  name can never equal an extensionless executable name, so it excludes nothing.
  Harmless (the host's own executable can't appear in those subdirs anyway) but
  misleading dead code. Fix or remove.
- **`loadURL` ignores its `id` parameter** (`URLItems.swift:14-17`): takes a
  `typeIdentifier` arg but hard-codes `UTType.fileURL.identifier` in the
  `loadItem` call. False contract — use `id` or drop the parameter.
- **Pipe output can truncate** (`ProcessHelper.swift:56-79`): `readabilityHandler`
  appends async on queue `Q`; after `waitUntilExit()` the handlers are nil'd and
  handles closed with no final drain, so bytes buffered just before exit can be
  lost on large `objdump` output. Fix: synchronous `readDataToEndOfFile()` drain
  before teardown, or drop the handler approach for a joined background read.
- **Unbounded binary read** (`BundleFeatureDetectionOperation.swift:479-543`):
  `Data(contentsOf:options:[.mappedIfSafe])` falls back to a full in-RAM read for
  non-mmap-safe files (network volumes, huge binaries), then iterates byte-by-byte
  building a String — multi-GB Unity/Electron binaries can blow memory. Fix: read
  a bounded prefix via `FileHandle` (`min(fileSize, limit)`).
- **`RunLoop.main.perform` is mode-sensitive** (`BundleFeatureDetectionOperation.swift:71-84`):
  unlike `DispatchQueue.main.async`, these blocks are deferred during modal panels,
  menu tracking, and live resizing, stalling UI state. Switching to
  `DispatchQueue.main.async` also removes the conditions enabling the disputed
  semaphore deadlock below.
- **Operation runs on after its window closes** (`BundleFeatureDetectionOperation.swift:62-84`):
  `resume()` strongly captures `self`; closing a window mid-scan leaves the
  background work (and objdump/string scan) running and mutating state. Fix: a
  cancellation flag checked between phases.
- **Malformed bundles conflated with non-apps** (`BundleFeatureDetectionOperation.swift:122-139`):
  a `.app` with a plist but a missing/deleted executable is reported as
  `notAnApplication`, discarding the structure/plist signals that could still be
  shown. Fix: run Phases 1–2 before requiring `executableURL`.

---

## Disputed (one verifier dissented — worth a look)

- **Semaphore-wait + `RunLoop.main.perform` deadlock** (`…:459-465`): the impact
  reviewer argued the deadlock only manifests in specific run-loop modes. Either
  way, the `RunLoop` → `DispatchQueue.main` fix (carry techs as a background local) removes it.
- **`@ObservedObject` + stored `WindowState` instead of `@StateObject`**
  (`ContentView.swift:14-19`): works today, but SwiftUI may recreate the struct
  and silently drop in-flight detection. Consider `@StateObject`.
- **Catalyst plist heuristic too strict** (`…:407-410`): requires
  `minimumSystemVersion == nil`, which real Catalyst apps usually *set* — so the
  branch rarely fires and falls through to `.macOS`. The reliable `iOSSupport`
  dependency-path check still covers it.
- **`Data` Int-subscript assumes 0-based** (`…:519-527`): safe for
  `Data(contentsOf:)` today; fragile if ever fed a slice. Use `withUnsafeBytes`.
- **Permission/sandbox read failures swallowed** (`fm.ls`, `…:580-587`):
  `(try? …) ?? []` collapses access-denied into "empty", indistinguishable from a
  bare bundle. Consider surfacing a "partial scan" state + security-scoped access.
- **objdump dependency-line parser assumptions** (`OTool.swift:127-137`): relies on
  leading-whitespace lines and `lastIndex(of: "(")`; brittle across objdump
  versions. Also the transitive-walk dedup snapshots at entry, re-scanning shared
  subtrees (`OTool.swift:51-109`) — a live `visited: Set<String>` would fix both
  correctness-of-intent and wasted work.

---

## Suggested order of attack

1. **Crash/robustness first:** #1 (About panel), #3 (NSException), #2 (timeout). Small, high impact.
2. **Correctness:** #5 (nested-app async read) and the no-op filter; `loadURL` `id`.
3. **Coverage wins:** Unreal (#6), decouple Rust/Tauri, Go, broaden Qt — these
   exercise already-built UI and visibly improve results.
4. **Hardening:** shell-mode default (#4), pipe drain, bounded binary read,
   `RunLoop` → `DispatchQueue.main`.
