# AppXray — agent notes

macOS app (SwiftUI views, AppKit lifecycle, macOS 12+) that inspects `.app`
bundles and reports the frameworks/languages/runtimes they're built with.
Architecture walkthrough: `Sources/AppXray/README.md`. User-facing scope:
`README.md`.

## Build & test

- Prerequisite (once per checkout): `LLVM/llvm-objdump` must exist.
  `cp "$(xcrun --find llvm-objdump)" LLVM/llvm-objdump`
- Build: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build`
- Test:  `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests`
- There is no SwiftPM package; everything goes through the Xcode project.

## Hard rules (violating these has caused real bugs)

1. **Detection is additive and era-aware.** A technology keeps every
   detection surface it ever had; new markers are added alongside old ones,
   never replacing them. Absence of a newer marker is not absence of the
   technology. Prefer markers that are unambiguous across eras (GLib alone
   is NOT GTK; `Reactive*` is NOT React). Read the "Detection signatures are
   versioned" section of `Sources/AppXray/README.md` before touching any
   matcher, and add a fixture test per new surface in
   `Tests/AppXrayTests/DirectoryScanTests.swift`.
2. **Subprocesses never default through a shell.** `Process.launch(at:with:using:)`
   defaults to a direct argv exec; keep it that way. If a shell is ever
   truly needed, arguments are single-quoted by `shellCommand`. Bundle paths
   legally contain spaces, quotes, and metacharacters.
3. **UI state is published in one main-thread hop.** The detection pipeline
   accumulates into locals and publishes once via `DispatchQueue.main.async`
   (never `RunLoop.main.perform` — it stalls in modal/menu/resize run-loop
   modes). No cross-thread reads of `@Published` members.
4. **The scanned bundle is untrusted input.** Bounded reads only
   (`binaryScanLimit`), objdump runs under a timeout watchdog, and the app
   stays sandboxed with read-only user-selected file access. Don't add
   entitlements or unbounded reads to make a feature easier.

## Conventions

- Two-space indentation; comments explain *why*, not *what*.
- Plain Unicode / SF Symbols in UI strings; no emoji in code.
- Adding a technology currently means touching several lockstep sites
  (OptionSet flag, `allKnown`, `displayName`, `symbolName`, a category array
  in `DetectedTechnologies.swift`, optionally `SummaryView` texts and the
  README table). Keep them consistent — the UI drops flags that lack a
  `displayName`.

## Plans

`plans/` holds advisor-written implementation plans (see `plans/README.md`
for order/status). Executors follow a plan's steps and STOP conditions
exactly and update the status table when done.
