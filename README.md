# AppXray

**Drop any macOS application to see what makes it tick.**

AppXray is a native macOS app that inspects `.app` bundles (and bare Mach-O executables) and tells you, in plain language, what they're built with. Drag an app onto the window and AppXray scans its bundle structure, linked libraries, Info.plist, and — when needed — the raw bytes of the executable to identify the **frameworks**, **languages**, **runtimes**, and **distribution tooling** behind it.

It started life as a small "is this AppKit or SwiftUI?" curiosity and has grown into a broad fingerprinting tool that recognizes everything from Electron and Flutter to Unity, Tauri, Wails, .NET, and statically-linked Qt.


## What it detects

AppXray groups its findings into four categories. Each detected technology is listed individually in the results, with its own SF Symbol icon.

### Frameworks & UI toolkits

| Technology | Notes |
|------------|-------|
| **AppKit** | The classic macOS UI framework |
| **UIKit** | iOS UI framework (seen on Catalyst / iOS-on-Mac apps) |
| **SwiftUI** | Apple's declarative UI framework |
| **WebKit** | System web view |
| **Carbon** | Legacy macOS C API |
| **Automator** | Automator applets |
| **Mac Catalyst** | iPad apps brought to the Mac via UIKit + AppKit |
| **iOS on Mac** | Unmodified iOS apps running on Apple Silicon |
| **Electron** | Chromium + Node.js desktop shell (VS Code, Slack, …) |
| **CEF (Chromium)** | Chromium Embedded Framework (Spotify, Steam, …) |
| **NW.js** | node-webkit, Electron's older cousin |
| **Flutter** | Google's cross-platform UI toolkit |
| **Tauri** | Rust core + the system WebView |
| **Wails** | Go core + the system WebView |
| **React Native** | JS/React with native views (incl. Hermes) |
| **Capacitor** | Ionic/Capacitor web-to-native bridge |
| **Qt** | The Qt C++ framework, including statically-linked and non-standard layouts |
| **wxWidgets** | Cross-platform C++ widgets |
| **GTK** | The GTK toolkit (GIMP-style apps) |
| **SDL** | Simple DirectMedia Layer (games, emulators) |
| **JavaFX** | Java's modern UI toolkit |
| **Platypus** | Shell-script-wrapped apps |

### Languages

| Technology | Notes |
|------------|-------|
| **Swift** | Detected from `libswiftCore` |
| **Objective-C** | Detected from `libobjc` |
| **C++** | Detected from `libc++` |
| **JavaScript** | Implied by Electron / CEF / React Native / Capacitor / NW.js |
| **Python** | Bundled `Python.framework` / `libpython` |
| **Java** | Bundled JRE, `.jar` payloads, or classic `Java`/`Eclipse` layouts |
| **Rust** | Tauri markers or general Rust toolchain strings |
| **Go** | Wails markers or Go build-ID strings |
| **Kotlin** | Kotlin/Native symbols |
| **AppleScript** | Compiled `.scpt` scripts in `Resources/Scripts` |

### Runtimes & game engines

| Technology | Notes |
|------------|-------|
| **Unity** | `UnityPlayer.dylib`, IL2CPP, `globalgamemanagers` |
| **Godot** | `.pck` packages or an embedded PCK in the executable |
| **Unreal Engine** | `-Mac-Shipping` executables, `UE4`/`UE5` payloads |
| **.NET** | CoreCLR, single-file AppHosts, MAUI assemblies |
| **Avalonia** | The cross-platform .NET UI framework |
| **Mono** | Mono / Xamarin.Mac runtime |

### Distribution & tooling

| Technology | Notes |
|------------|-------|
| **Sparkle** | The dominant non-App-Store auto-updater |
| **Squirrel** | The updater commonly bundled with Electron apps |

AppXray also reports the **platform type** (macOS, Mac Catalyst, or iOS-on-Mac) and lists any **embedded/nested apps** it finds (helper apps, login items, framework-hosted apps), analyzing each of them too.


## How it works

Detection runs on a background thread through a four-phase pipeline, ordered from fastest to slowest. Phases accumulate into a single result that's published to the UI in one hop, so the window never flickers through partial states.

1. **Bundle structure scan** — pure filesystem checks for known paths and file markers. Examples: `Frameworks/Electron Framework.framework`, `FlutterMacOS.framework`, `Resources/app.asar`, `Data/globalgamemanagers` (Unity), `*.pck` (Godot), `Contents/MonoBundle`, `Contents/UE5`, `Resources/Scripts/*.scpt` (AppleScript). This phase also handles Qt in non-standard locations (e.g. Ableton's `Contents/Qt/lib`) and managed-DLL scans across `Frameworks`, `MonoBundle`, and `Resources`.

2. **Info.plist analysis** — reads the bundle's property list for identifiers like the Electron ASAR-integrity key, `DTPlatformName == iphoneos` (iOS-on-Mac), Automator/Carbon flags, and Java markers.

3. **Dependency analysis** — runs LLVM [`objdump`](https://en.wikipedia.org/wiki/Objdump) (`--macho --dylibs-used`) on the main executable and walks its **transitive** dependencies, deduplicating along the way. Linked libraries reveal Swift, Objective-C, C++, AppKit, SwiftUI, WebKit, Qt, SDL, GTK, Sparkle, Squirrel, and more. Catalyst is confirmed when UIKit is loaded from an `/System/iOSSupport/` path.

4. **Binary string analysis** — a last resort for stacks with no reliable on-disk signal: Tauri/Rust, Wails/Go, Kotlin/Native, embedded-PCK Godot, .NET single-file AppHosts, and statically-linked Qt. To stay fast on multi-gigabyte game and Electron binaries, AppXray reads only a **bounded prefix** of the file and skips this phase entirely when a definitive heavy framework (Electron, CEF, Flutter, Unity, Unreal, …) is already known.

The scan also recurses into **nested `.app` bundles** under `Contents/MacOS` and `Contents/Frameworks`, can be **cancelled** mid-flight (when you close the window or drop a new file), and holds **security-scoped access** so sandboxed reads of the dropped bundle succeed.


## About the app itself

AppXray is a SwiftUI macOS application using an AppKit lifecycle (`AppDelegate` + a storyboard for the menu bar). Each window owns a small state machine that drives the UI between the empty drop zone, a loading spinner, the results screen, and the "not an executable" error state. It targets **macOS 12+**. See [`Sources/AppXray/README.md`](Sources/AppXray/README.md) for an architecture walkthrough.


## Third-party software

- LLVM objdump: [license](LLVM/LLVM-LICENSE.TXT)

A full list is available in the app via **AppXray ▸ About ▸ Third-Party Licenses**.


## Building

An `llvm-objdump` binary needs to be present in the `LLVM` folder before building. The binary bundled with Xcode works fine for development:

```
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump
```

Copy or symlink it into `LLVM/`, then open `AppXray.xcodeproj` and build.

> **Note:** The app icon set is intentionally empty pending a new icon; the project builds and runs without it (falling back to the system app icon).


## Origin

Based on the original [5 GUIs](https://zeezide.com/en/products/5guis/index.html) by [ZeeZide](http://zeezide.de), inspired by [Joe Groff's tweet](https://twitter.com/jckarter/status/1310412969289773056) naming macOS "Five GUIs" for its mix of UI frameworks. AppXray keeps that spirit but covers far more than five — hence the rename. The original work is licensed under Apache 2.0; ZeeZide's attribution is retained in the source, this README, and the in-app About panel.
