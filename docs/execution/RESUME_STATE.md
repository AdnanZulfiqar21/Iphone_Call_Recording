# Resume state

**Updated:** 1 October 2026
**Branch:** `main` (P00–P12 merged from `phase/p08-app-build`)
**Authorization:** `docs/execution/AUTONOMOUS_BUILD_AUTHORIZATION.md`

## Where things are

- Core package (`Packages/CallCaptureCore`) — domain logic for P02–P07, tested locally with Docker `swift:6.2` and on GitHub `ubuntu-latest`.
- Media layer (`CallCaptureMedia`) — ScreenCaptureKit engine, segmented writer, assembler, validator. Tested on the `xcode-27` runner (`swift test` on macOS 27) and compiled for the iOS 27 device SDK.
- App (`App/`, `Widgets/`, `project.yml`) — SwiftUI app, Live Activity, StoreKit; project generated in CI by XcodeGen.

## How to continue

1. Read `docs/execution/PROGRESS.md` for phase status and the latest CI run.
2. Check the latest CI run: `gh run list --branch phase/p00-foundation --limit 3`.
3. Fix any failing job; rerun; update PROGRESS.md with actual results.
4. Local fast loop for core logic (Windows + Docker):
   `docker run --rm -v "<repo>/Packages/CallCaptureCore:/pkg" -w /pkg swift:6.2 swift test --build-path /tmp/build`
5. App build/test only runs on the `xcode-27` runner (no local Mac).

## Next concrete action

1. Independent review of `main` using `docs/reviews/CURSOR_REVIEW_INDEX.md` (handoff, UX18, F-UX08-01).
2. Owner provides Apple Developer / App Store Connect access and final bundle ID (BLOCKERS B01, B04).
3. P13: signed archive + TestFlight; then P14 physical iPhone validation per roadmap section 19.

Focused CI reruns: `gh workflow run ci.yml --ref main -f only_testing=CallCaptureUITests/CallCaptureUITests/<test>`.
