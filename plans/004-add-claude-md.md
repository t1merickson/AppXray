# Plan 004: Add a repo-level CLAUDE.md so agents inherit the project's hard-won rules

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 57d746e..HEAD -- Sources/AppXray/README.md README.md`
> If those files changed since this plan was written, re-verify that the
> CLAUDE.md content below still matches what they document (especially the
> build/test commands and the era-aware section) before writing the file.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (adds one documentation file)
- **Depends on**: plans/001-detection-test-baseline.md (the test command referenced below must exist)
- **Category**: dx
- **Planned at**: commit `57d746e`, 2026-07-03

## Why this matters

This repo is routinely worked on by coding agents, and its most important
invariants are *doctrine*, not types: detection must stay additive and
era-aware, subprocesses must never default through a shell, UI state must be
published in a single main-thread hop. Today that doctrine lives spread across
two READMEs and an audit document; an agent that doesn't read all three can
regress it (that exact class of regression — signature edits without era
awareness — is what `Sources/AppXray/README.md`'s era section was written to
prevent). A `CLAUDE.md` at the repo root is loaded into every Claude Code
session automatically and is the standard place for build commands plus
non-negotiable rules.

## Current state

- No `CLAUDE.md` or `AGENTS.md` exists anywhere in the repo (`ls` the root to confirm).
- `README.md` — user-facing: what is detected, how the four phases work, the
  build prerequisite (`llvm-objdump` must be copied into `LLVM/` before building).
- `Sources/AppXray/README.md` — the architecture walkthrough, including the
  normative section **"Detection signatures are versioned (era-aware)"** with
  its two rules (additive detection; era-ambiguous markers) — the single most
  important thing an agent must not violate.
- `AUDIT.md` — a completed audit; historical context, not current instructions.
- Verified commands (do not invent others):
  - Build: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build`
  - Test (exists once plan 001 lands): `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests`
  - objdump prerequisite: `cp "$(xcrun --find llvm-objdump)" LLVM/llvm-objdump`

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Confirm test target exists | `xcodebuild -list` | targets include `AppXrayTests` |
| Sanity-run both commands you are documenting | see above | build + tests succeed |

## Scope

**In scope** (the only files you should create/modify):
- `CLAUDE.md` (create, repo root)
- `plans/README.md` (status row)

**Out of scope**:
- Rewriting or moving content out of the two READMEs — CLAUDE.md points at
  them, it does not replace them.
- `.claude/` settings, hooks, or permissions files.

## Git workflow

- Branch: `advisor/004-claude-md`
- One commit, e.g. "Add CLAUDE.md with build/test commands and detection doctrine"
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Write `CLAUDE.md` at the repo root

Use exactly this content (verify the two commands still work first; if the
test scheme does not exist, STOP — plan 001 hasn't landed):

```markdown
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
```

**Verify**: `test -f CLAUDE.md && head -3 CLAUDE.md` → shows the header;
both documented commands were run and succeeded during this step.

## Test plan

Not applicable (documentation). The verification is that every command quoted
in the file was executed successfully before committing.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `CLAUDE.md` exists at repo root with the four hard rules and both commands
- [ ] Both quoted commands were run in this session and succeeded (paste outputs in your report)
- [ ] `git diff --stat` touches only `CLAUDE.md` + `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `xcodebuild -list` does not show `AppXrayTests` (plan 001 not landed) — the
  file must not document a command that fails.
- A `CLAUDE.md` or `AGENTS.md` already exists (created since this plan was
  written) — reconcile, don't overwrite.

## Maintenance notes

- When plan 005 adds CI, append a line to the "Build & test" section naming
  the workflow file.
- If the technology-metadata registry refactor (deferred finding DEBT-04 in
  `plans/README.md`) ever lands, update rule/convention text about lockstep sites.
