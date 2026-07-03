# Plan 005: Add GitHub Actions CI that builds the app and runs the test suite

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 57d746e..HEAD -- AppXray.xcodeproj .github`
> If a workflow already exists under `.github/workflows/`, STOP — reconcile
> instead of adding a duplicate.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (adds a workflow file; no product code changes)
- **Depends on**: plans/001-detection-test-baseline.md (the test scheme it runs)
- **Category**: dx
- **Planned at**: commit `57d746e`, 2026-07-03

## Why this matters

The repo lives on GitHub (`github.com/t1merickson/AppXray`) but has no CI —
nothing catches a broken build or failed test on push. Once plan 001's suite
exists, the marginal cost of running it on every push is one workflow file,
and the detection engine's rapid signature churn (6 of the last 10 commits) is
exactly the change pattern CI protects.

## Current state

- No `.github/` directory exists.
- The build has one non-standard prerequisite: `LLVM/llvm-objdump` is
  **gitignored** (see `.gitignore` line `LLVM/llvm-objdump`) and must be
  provided before building — the app target's "Bundle Objdump" copy phase
  needs it. `README.md` ("Building") documents sourcing it from the Xcode
  toolchain; on a runner: `cp "$(xcrun --find llvm-objdump)" LLVM/llvm-objdump`.
- Local signing is ad-hoc (`xcodebuild` notes "Disabling hardened runtime with
  ad-hoc codesigning") — no certificates are required to build or test.
- Verified commands:
  - Build: `xcodebuild -project AppXray.xcodeproj -scheme AppXray -configuration Debug build`
  - Test: `xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests`
- Unit tests are host-less logic tests (no app launch, no sandbox involvement),
  so they run cleanly on a headless runner.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Validate workflow syntax locally | `gh workflow list` (after push) or a YAML parse: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` | exit 0 |
| Local dry-run of the CI steps | run the three commands from the workflow locally in order | build + test succeed |

## Scope

**In scope** (the only files you should create/modify):
- `.github/workflows/ci.yml` (create)
- `plans/README.md` (status row)

**Out of scope**:
- Release/archive/notarization jobs, caching DerivedData, matrix builds across
  Xcode versions — keep the first workflow minimal.
- Any change to project build settings to appease CI. If the runner needs a
  setting changed, that's a STOP condition.

## Git workflow

- Branch: `advisor/005-github-actions-ci`
- One commit, e.g. "Add CI: build and test on push"
- Do NOT push or open a PR unless the operator instructed it. (Note: the
  workflow only takes effect once pushed; local verification is the YAML parse
  plus running the same commands.)

## Steps

### Step 1: Create the workflow

Write `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Provide llvm-objdump (gitignored build prerequisite)
        run: cp "$(xcrun --find llvm-objdump)" LLVM/llvm-objdump

      - name: Build
        run: |
          xcodebuild -project AppXray.xcodeproj -scheme AppXray \
            -configuration Debug build

      - name: Test
        run: |
          xcodebuild test -project AppXray.xcodeproj -scheme AppXrayTests
```

**Verify**: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` → exit 0.

### Step 2: Dry-run the exact steps locally

Run the three `run:` commands from the workflow, in order, from a clean state
(`rm -f LLVM/llvm-objdump` first to prove the copy step suffices — note this
deletes a gitignored local artifact only, and the copy step restores it).

**Verify**: all three commands succeed; final output `** TEST SUCCEEDED **`.

## Test plan

The workflow *is* the test infrastructure; local dry-run in step 2 is its test.
First real validation happens on the first push — whoever pushes should check
the Actions tab and report a red run as a bug against this plan.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.github/workflows/ci.yml` exists and parses as YAML
- [ ] The three workflow commands, run locally in order from a clean objdump state, all succeed
- [ ] `git diff --stat` touches only `.github/workflows/ci.yml` + `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `xcodebuild -list` does not show `AppXrayTests` (plan 001 not landed).
- The local dry-run fails in a way that would require changing project build
  settings (e.g. signing) — report the exact error instead of editing the project.
- A workflow file already exists under `.github/workflows/`.

## Maintenance notes

- `macos-15` pins the runner image; when GitHub retires it, bump the label —
  nothing else in the workflow is version-sensitive.
- If plan 004's `CLAUDE.md` exists, add a line under its "Build & test"
  section pointing at this workflow.
- Deferred: caching DerivedData (build is small; not worth cache invalidation
  complexity yet) and a release/notarization job.
