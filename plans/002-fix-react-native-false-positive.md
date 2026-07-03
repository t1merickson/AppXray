# Plan 002: Stop ReactiveCocoa-family frameworks from being detected as React Native

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 57d746e..HEAD -- Sources/AppXray/BundleFeatureDetectionOperation.swift Tests/AppXrayTests/`
> If the in-scope files changed since this plan was written, compare the
> "Current state" excerpt against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (narrowing one matcher; regression tests pin both directions)
- **Depends on**: plans/001-detection-test-baseline.md (provides the test target the regression tests go into)
- **Category**: bug
- **Planned at**: commit `57d746e`, 2026-07-03

## Why this matters

Phase 1 of the detection pipeline flags **any** framework whose name starts
with `React` as React Native. `ReactiveCocoa.framework`, `ReactiveSwift.framework`,
and `ReactiveObjC.framework` — popular FRP libraries bundled by plenty of
ordinary Objective-C/Swift Mac apps — all start with `React`, so those apps are
misreported as React Native + JavaScript. This is the same class of bug as the
GLib-misread-as-GTK false positive already fixed in commit `bf1fee0`: an
over-broad prefix swallowing an unrelated library family.

## Current state

- `Sources/AppXray/BundleFeatureDetectionOperation.swift:307-315` — inside the
  `Contents/Frameworks` filename loop of `processDirectoryContents`:

  ```swift
  // React Native -- exact frameworks plus case-insensitive Hermes / React*
  if filename == "React.framework"
  || filename == "React-Core.framework"
  || filename.hasPrefix("React")
  || filename.lowercased().hasPrefix("hermes") {
    detected.insert(.reactNative)
    detected.insert(.javascript)
    continue
  }
  ```

  The third condition (`hasPrefix("React")`) makes the first two redundant and
  over-matches the Reactive* family.

- **Design constraint you must honor** (from `Sources/AppXray/README.md`,
  "Detection signatures are versioned (era-aware)"): detection is *additive*;
  each era's marker surface must keep matching. Real React Native macOS bundles
  ship frameworks named `React.framework` (classic/JSC era), split pods like
  `React-Core.framework` / `React-RCTText.framework`, `ReactCommon.framework`,
  and `Hermes.framework`/`hermes.framework` (New Architecture era). The fix
  must keep all of those matching while excluding `Reactive*`.

- Repo conventions: two-space indent; comments state the *why*, including
  explicit notes about what a pattern deliberately does NOT match (see the GTK
  comment at lines 321-323 of the same file for the exemplar to imitate).

- Test conventions: fixture-based Phase 1 tests live in
  `Tests/AppXrayTests/DirectoryScanTests.swift` (created by plan 001), using the
  `BundleFixture` helper — model the new cases on the existing GTK/GLib pair.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build app | `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Run tests | `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only files you should modify):
- `Sources/AppXray/BundleFeatureDetectionOperation.swift` (the one matcher block)
- `Tests/AppXrayTests/DirectoryScanTests.swift` (add cases)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- `scanDependencies` (Phase 3) — it has no React matcher at all; adding one is
  a coverage feature, not this bug fix.
- Every other matcher in the filename loop, however tempting a tidy-up looks.
- `README.md` technology tables — the detected set is unchanged.

## Git workflow

- Branch: `advisor/002-react-native-false-positive`
- One commit; imperative subject, e.g. "Fix React Native false positive: Reactive* is not React"
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Narrow the matcher

Replace the block quoted in "Current state" with:

```swift
// React Native across eras: React.framework (classic/JSC), split pods
// (React-Core, React-RCTText, ...), ReactCommon, and Hermes (New
// Architecture). "Reactive*" (ReactiveCocoa/Swift/ObjC) is an unrelated
// FRP family and must NOT match.
if filename == "React.framework"
|| filename.hasPrefix("React-")
|| filename.hasPrefix("React_")
|| filename.hasPrefix("ReactCommon")
|| filename.hasPrefix("ReactNative")
|| filename.lowercased().hasPrefix("hermes") {
  detected.insert(.reactNative)
  detected.insert(.javascript)
  continue
}
```

**Verify**: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` → `** BUILD SUCCEEDED **`

### Step 2: Add regression tests

In `Tests/AppXrayTests/DirectoryScanTests.swift`, add fixture cases:

Must set `.reactNative` (and `.javascript`):
- `Contents/Frameworks/React.framework`  (exists from plan 001 — keep it)
- `Contents/Frameworks/React-Core.framework`
- `Contents/Frameworks/ReactCommon.framework`
- `Contents/Frameworks/Hermes.framework` (exists from plan 001 — keep it)

Must NOT set `.reactNative` and must NOT set `.javascript`:
- `Contents/Frameworks/ReactiveCocoa.framework`
- `Contents/Frameworks/ReactiveSwift.framework`
- `Contents/Frameworks/ReactiveObjC.framework`

**Verify**: `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` → `** TEST SUCCEEDED **`, test count increased by ≥ 5.

## Test plan

Covered by step 2 — three negative regression cases (the bug), two new positive
era cases (additivity preserved). Pattern: the GLib/GTK negative case from plan 001.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` → `** TEST SUCCEEDED **`, including the 7 cases above
- [ ] `grep -n 'hasPrefix("React")' Sources/AppXray/BundleFeatureDetectionOperation.swift` returns no matches (the bare prefix is gone)
- [ ] `git diff --stat` touches only the two in-scope code files + `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The matcher block at lines ~307-315 doesn't match the "Current state" excerpt.
- `Tests/AppXrayTests/DirectoryScanTests.swift` does not exist (plan 001 has
  not landed) — this plan must not proceed without the test target.
- Any *other* existing test fails after the change — the narrowed matcher
  should affect nothing else; a surprise failure means a wrong assumption.

## Maintenance notes

- If a future React Native era ships a new framework name, add a prefix *and*
  a fixture case together (era-aware rule in `Sources/AppXray/README.md`).
- Reviewer focus: confirm no other `hasPrefix` matcher in the same loop has the
  same over-match shape (`Qt`, `libwx_`, `libgtk-` were checked during the
  audit and are safely specific).
