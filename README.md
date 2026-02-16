<h2>5 GUIs
  <img src="5GUIs/Assets.xcassets/AppIcon.appiconset/5GUIs-256.png"
           align="right" width="128" height="128" />
</h2>

Drop any macOS application to see what makes it tick.

5 GUIs scans app bundle structure, linked libraries, and binary contents to identify the frameworks, languages, and runtimes behind any `.app`.

### What it detects

| Category | Technologies |
|----------|-------------|
| **Frameworks** | AppKit, UIKit, SwiftUI, WebKit, Carbon, Automator, Electron, Mac Catalyst, Qt, wxWidgets, CEF, Flutter, Tauri, React Native, Capacitor, Platypus |
| **Languages** | Swift, Objective-C, C++, Python, Java, AppleScript, Rust, JavaScript |
| **Runtimes** | Unity, Godot, Unreal Engine, .NET, Avalonia, Mono |

Results are grouped by category, with each detected technology listed individually with its own icon.


### How it works

Detection runs through a four-phase pipeline, ordered from fast to slow:

1. **Bundle structure scan** -- filesystem checks for known paths (e.g. `Frameworks/Electron Framework.framework`, `Resources/flutter_assets`)
2. **Info.plist analysis** -- reads the bundle's property list for identifiers like `LSUIElement`, `DTSDKName`, and `NSAppleScriptEnabled`
3. **Dependency analysis** -- runs LLVM [`objdump`](https://en.wikipedia.org/wiki/Objdump) on the main executable and walks transitive dependencies looking for linked frameworks and libraries
4. **Binary string analysis** -- searches for embedded strings as a last resort (currently used for Tauri/Rust when library linking is ambiguous)

5 GUIs itself is a SwiftUI macOS application using an AppKit lifecycle (AppDelegate + storyboard menus). It targets macOS 12+.


### 3rd party software

- LLVM objdump: [license](LLVM/LLVM-LICENSE.TXT)


### Building

An `llvm-objdump` binary needs to be present in the `LLVM` folder before building. The binary bundled with Xcode works fine for development:

```
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump
```

Copy or symlink it into `LLVM/`, then open `5GUIs.xcodeproj` and build.


### Origin

Based on the original [5 GUIs](https://zeezide.com/en/products/5guis/index.html) by [ZeeZide](http://zeezide.de), inspired by [Joe Groff's tweet](https://twitter.com/jckarter/status/1310412969289773056) naming macOS "Five GUIs" for its mix of UI frameworks.
