# Plan 003: Stop spawning objdump on system libraries that don't exist on disk

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 57d746e..HEAD -- Sources/AppXray/Utilities/OTool.swift`
> If the file changed since this plan was written, compare the "Current state"
> excerpt against the live code before proceeding; on a mismatch, treat it as
> a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (skips process spawns that are guaranteed to fail; detection input is unchanged)
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `57d746e`, 2026-07-03

## Why this matters

Phase 3 walks the scanned app's transitive dependencies by running the bundled
`llvm-objdump` on each linked library. Since macOS 11, system libraries
(`/System/Library/...`, `/usr/lib/...`) do not exist as files on disk — they
live only inside the dyld shared cache. The walk still spawns an objdump
process for every unique system dependency; each spawn fails with a non-zero
exit, gets caught, and prints an error. A typical app links 20–80 system
libraries, so every scan burns dozens of doomed process spawns (roughly 0.5–2 s
of wall time) and floods the console with `ERROR: objdump result:` /
`ERROR: ignoring nested error:` noise. Skipping files that don't exist is a
pure win: detection reads the dependency *names* (collected before the
recursion), so no signal is lost.

## Current state

- `Sources/AppXray/Utilities/OTool.swift` — the whole file is the dependency
  walk. The relevant part of `run(objdump:against:nesting:maxNesting:into:scanned:)`:

  ```swift
  // OTool.swift:62-63 — names are collected BEFORE any recursion, so the
  // detection input (the dependency string list) is independent of the walk:
  let directDeps = try run(objdump: objdump, against: url)
  result.formUnion(directDeps)
  ```

  ```swift
  // OTool.swift:104-121 — the else branch resolves absolute paths (system
  // libraries land here) and recurses without checking existence:
  else {
    dependencyURL = URL(fileURLWithPath: dep, relativeTo: url)
  }

  // Skip subtrees already walked via another parent (live dedup).
  guard !scanned.contains(dependencyURL.resolvingSymlinksInPath().path) else {
    continue
  }

  do {
    try run(objdump: objdump, against: dependencyURL,
            nesting: nesting + 1, maxNesting: maxNesting,
            into: &result, scanned: &scanned)
  }
  catch {
    print("ERROR: ignoring nested error:", error)
  }
  ```

  Note the `@rpath` / `@executable_path` / `@loader_path` branches above this
  (lines 87-98) already existence-check via `checkRelname`; only the absolute-path
  branch is missing the check.

- `Sources/AppXray/Utilities/ProcessHelper.swift:63-68` — a missing launch
  *tool* path is guarded; a missing *argument* path is not (objdump itself
  runs and exits non-zero). That is why each phantom dependency costs a real
  process spawn.

- Repo conventions: two-space indent; short comments stating the why (see the
  existing "Skip subtrees already walked" comment for tone).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Tests (if plan 001 has landed) | `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests` | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only files you should modify):
- `Sources/AppXray/Utilities/OTool.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- `ProcessHelper.swift` — the general-purpose launcher should keep failing
  loudly on bad argument paths; the fix belongs at the call site that knows
  the path is a filesystem dependency.
- Parallelizing the walk, changing `maxNesting`, or any other objdump flag —
  considered and rejected during the audit (see plans/README.md).
- The dedup logic (`scanned`) and the `@`-prefix resolution branches.

## Git workflow

- Branch: `advisor/003-skip-phantom-deps`
- One commit; imperative subject, e.g. "Skip objdump on dependencies that don't exist on disk"
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the existence guard before recursing

In `Sources/AppXray/Utilities/OTool.swift`, immediately after the
`guard !scanned.contains(...)` dedup guard (line ~109-111) and before the
`do { try run(...) }` recursion, insert:

```swift
// System libraries (/usr/lib, /System/Library) have lived only in the
// dyld shared cache since macOS 11 -- there is no file to objdump, so
// don't pay a doomed process spawn. Their names are already in `result`.
guard FileManager.default.fileExists(atPath: dependencyURL.path) else {
  continue
}
```

(The `@`-relative branches already checked existence; re-passing them through
this guard is harmless and keeps the logic in one place.)

**Verify**: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` → `** BUILD SUCCEEDED **`

### Step 2: Confirm behavior on a real app

Run the freshly built binary's scan path indirectly — build products land in
DerivedData; instead of launching the GUI, verify via the unit tests if plan
001 has landed (`xcodebuild test -scheme AppXrayTests` → `** TEST SUCCEEDED **`).

If plan 001 has NOT landed, verification is the build plus a code-reading
check: `grep -n "fileExists(atPath: dependencyURL.path)" Sources/AppXray/Utilities/OTool.swift`
→ exactly one match, positioned between the `scanned.contains` guard and the
recursive `run` call.

**Verify**: command above → expected output.

## Test plan

No new automated tests: exercising the walk requires real Mach-O binaries with
resolvable dependency trees, which fixture files can't fake cheaply and
installed-app paths would make environment-dependent. The guard is
straight-line code whose failure mode (skipping a file that *does* exist) is
excluded by using the same `dependencyURL.path` the recursion itself would
open. If plan 001's suite exists, run it as a no-regression check.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build` → `** BUILD SUCCEEDED **`
- [ ] `grep -c "fileExists(atPath: dependencyURL.path)" Sources/AppXray/Utilities/OTool.swift` → `1`
- [ ] The guard sits after the `scanned.contains` dedup and before the recursive `run` call (visual check of the diff)
- [ ] `git diff --stat` touches only `OTool.swift` + `plans/README.md`
- [ ] If `AppXrayTests` exists: `xcodebuild test -scheme AppXrayTests` → `** TEST SUCCEEDED **`

## STOP conditions

Stop and report back (do not improvise) if:

- `OTool.swift` no longer matches the "Current state" excerpts (e.g. the walk
  was restructured since `57d746e`).
- You find yourself wanting to *also* filter which names go into `result` —
  that changes detection input and is explicitly not this plan.

## Maintenance notes

- If Apple ever re-materializes system libraries on disk (or the app starts
  scanning non-system roots with dangling symlinks), this guard silently skips
  them — which is still the right behavior, since the recursion would only
  fail anyway.
- Reviewer focus: the guard must use `dependencyURL` (the resolved path), not
  `dep` (the raw load-command string).
- Deferred follow-up (recorded in plans/README.md): the watchdog data race in
  `ProcessHelper.swift:97-112` — unrelated to this change, keep separate.
