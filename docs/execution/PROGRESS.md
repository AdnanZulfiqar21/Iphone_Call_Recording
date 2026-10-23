# Progress

**Next action:** independent review of `main` (B03) incl. UX18 and open finding F-UX08-01; then P13 TestFlight once the owner provides signing access (B01); then P14 physical testing.

Four separate statuses per phase (`AUTONOMOUS_BUILD_AUTHORIZATION.md`):
**Impl** = code written · **Build/Test** = checks actually executed (evidence) · **Review** = independent review · **Device** = physical iPhone.

| Phase | Impl | Build/Test (evidence) | Review | Device |
|---|---|---|---|---|
| P00 Foundation & tooling | DONE — XcodeGen project, CI (Linux + `xcode-27`), release audit | CI green for core (Linux), package (macOS 27 + iOS 27 device SDK) and app jobs | PENDING | N/A |
| P01 Platform research | DONE — `docs/platform/capture-path-decision.md` | ScreenCaptureKit exists only in the iOS 27.0 SDK; media module incl. `ScreenCaptureKitEngine` compiles for `generic/platform=iOS` (SDK_COMPILED) | PENDING | DEFERRED_TO_P14 |
| P02 Contracts, lifecycle, protection, design foundation | DONE | 58 core tests pass (Swift 6.2 Linux local + CI; macOS 27 CI) | PENDING | DEFERRED_TO_P14 |
| P03 CaptureEngine + synthetic adapter | DONE | SCK engine SDK_COMPILED; synthetic adapter drives simulator UI tests; absent from Release binary (audit) | PENDING | DEFERRED_TO_P14 |
| P04 MediaWriter, checkpoints | DONE — `SegmentedTrackWriter` (per source × part, HLS fMP4 segments), `SegmentCommitter` | App-hosted iOS simulator tests: per-track segment checkpoints, format-epoch parts, recovery from abandoned writer — PASS | PENDING | DEFERRED_TO_P14 |
| P05 Health, ledger, validator | DONE | Core health tests PASS; FULL validation detects a microphone hole in a real file (T06) — PASS after edit-segment fix | PENDING | DEFERRED_TO_P14 |
| P06 Store, recovery, deletion, migration | DONE | T23–T30 PASS (core); launch recovery UI test added | PENDING | DEFERRED_TO_P14 |
| P07 Diagnostics, resources | DONE — incl. runtime governor during capture with low-storage protected stop | T35/T36 + low-storage protected stop PASS (core); resource-pressure UI test PASS | PENDING | DEFERRED_TO_P14 |
| P08 Recording UI, setup, Settings, Live Activity | DONE | 15/15 UI tests PASS on iPhone 17 Pro (run 36833134634); layout tests PASS on iPhone 17e and iPhone 18 Pro Max | PENDING | DEFERRED_TO_P14 |
| P09 Library, player, export | DONE | 1,000-item library, real-media player with gap marker, export sheet — UI tests PASS | PENDING | DEFERRED_TO_P14 |
| P10 Privacy, security, accessibility | DONE | Contrast 32/32 (`docs/ux/contrast-report.md`); release audit 18/18; accessibility audit PASS; RTL run PASS | PENDING | DEFERRED_TO_P14 |
| P11 Commercial V1 | DONE — StoreKit 2, honest Pro scope (technical report, extra sorting) | Entitlement tests PASS; Pro screen UI test PASS | PENDING | DEFERRED_TO_P14 |
| P12 Complete build & audit (M1) | IMPLEMENTATION COMPLETE — see `docs/execution/M1_BUILD_AUDIT.md` | Non-device gates executed (above); UX gate in `docs/ux/ui-acceptance.md` | **INDEPENDENT_REVIEW_PENDING → M1 not yet accepted** | DEVICE_EVIDENCE_PENDING |
| P13 Signing / TestFlight (M2) | DONE for internal TestFlight — `device-build.yml`: signed archive (automatic signing, App Store Connect API key in the protected `Call Recording Application` environment), bundle IDs registered through the API (`scripts/asc_setup.py`), upload | **1.0.0 (16)** from `4281f7f` uploaded to App Store Connect (Device build run 39896555846); signed-app release audit PASS incl. iPhone-only check. Upload 14 was rejected by App Store validation (universal build, portrait only) — fixed. Processing/TestFlight availability: owner to confirm | — | DEVICE_EVIDENCE_PENDING (P14) |
| P14 Physical iPhone validation | IN PROGRESS — DT-01 run on 1.0.0 (16); findings DT01-1…4 fixed in code (`docs/execution/DEVICE_TEST_LOG.md`) | Fixes compile/test in CI; device re-test DT-02 pending a new TestFlight build | — | DT-01 recorded; DT-02 pending |
| P14–P16 | NOT STARTED (by design after M1/M2) | — | — | — |

## Test evidence log

| Date | Commit / run | Where | What | Result |
|---|---|---|---|---|
| 2026-10-01 | local | Docker `swift:6.2` | Core `swift test` | 58 passed |
| 2026-10-01 | run 36833134634 | GitHub `ubuntu-latest` (`swift:6.2`) | Core tests | PASS |
| 2026-10-01 | run 36833134634 | `xcode-27` (macOS 27, Xcode 27.0) | Package `swift test` + `xcodebuild -scheme CallCaptureCore-Package -destination generic/platform=iOS` (Release) | PASS / BUILD SUCCEEDED |
| 2026-10-01 | run 36833134634 | `xcode-27`, iPhone 17 Pro iOS 27.0 sim | `xcodebuild test` — 11 app-hosted Swift Testing tests (incl. 6 AVFoundation pipeline tests) + 15 UI tests | TEST SUCCEEDED |
| 2026-10-01 | run 36833134634 | iPhone 17e / iPhone 18 Pro Max sims | 3 layout-sensitive UI tests each | all passed (large run marked failed only by a post-run diagnostics-collection timeout; disabled since) |
| 2026-10-01 | run 36833134634 | `xcode-27` | Unsigned Release build `generic/platform=iOS` + `scripts/release_audit.sh` | BUILD SUCCEEDED; audit 18/18 PASS |
| 2026-10-01 | local | Python | `scripts/contrast_check.py` | 32/32 PASS |
| 2026-10-01 | run 36856930397 (`990f664`) | `xcode-27` | Full app job after writer race fix (T16 found it) | 11/11 + 16/16 + layouts + contrast + Release + audit PASS; job hit 90-min limit at upload |
| 2026-10-01 | run 36867785513 (`d7b2ddf`) | `xcode-27` | Full app job | all PASS except intermittent accessibility-audit flag (F-UX08-01) |
| 2026-10-01 | run 36879541190 (`9a15778`) | `xcode-27` | Focused dispatch: audit + layouts + contrast + Release + audit | all jobs green |
| 2026-10-01 | run 36885459935 (`cfe1ab3`, `main`) | `xcode-27` | Full app job | FAIL: T16 duration (intermittent) and F-UX08-01 audit; layouts, contrast, Release build, release audit PASS; issue details lost when artifacts expired |
| 2026-10-23 | run 39896552152 (`4281f7f`) | `xcode-27` | Full app job after writer fix | 11/11 app-hosted tests PASS incl. **T16** (0 samples dropped) and T06 (hole → new part `microphone.e1`); 15/16 UI tests (audit F-UX08-01 failed); small/large layouts, Increase Contrast, Release build, release audit 19/19 PASS |
| 2026-10-23 | runs 39924328190, 39929721266 (`20192e0`, `c3c81f5`) | `xcode-27` | Full app job after simulator cleanup | Release build 53–54 s (two earlier jobs lost there); layouts, Increase Contrast, Release build, audit PASS; only F-UX08-01 failed — evidence captured |

## Open findings (author-side)

| ID | Severity | Finding | Status |
|---|---|---|---|
| F-UX08-01 | SEV-3 | Accessibility audit intermittently flagged "Potentially inaccessible text" on Recordings (5 of 12 runs, also on `main`) | ROOT CAUSE FOUND (run 39929721266, OCR vs element evidence): with 8 seeded rows the 7th row sits partly behind the floating tab bar; the visible slice of its title is read as "Supr"/"Oct 2", which element detection cannot match to the row's element. Every other on-screen text matched an element. Not a missing element in the app. Test now audits a 5-row library and asserts no row is under the tab bar; long lists stay covered by `testLargeLibrarySearchFilter`. FIX PUSHED — awaiting CI |
| F-T16-01 | SEV-2 | T16 intermittently assembled a shorter file than fed. Test abandoned a sample after 1 s of backpressure; the writer had already advanced `lastAudioEnd` for it, so the hole was closed up instead of starting a new part. Same gap existed in production for writer-rejected samples | FIXED — writer restores `lastAudioEnd` on rejection; tests wait like the pipeline (bounded 10 s) and fail with counts, durations and segment ranges; T16 PASS in run 39896552152 |

## Defects found and fixed during non-device verification

- Writer: a rejected audio sample advanced the discontinuity clock, so the hole it left could be closed up in the part — the next accepted sample now starts a new part (F-T16-01).

- Writer: early-closed track part could miss its tail at Stop (race) — fixed (`990f664`).
- Validator: holes rendered as silence by decoders were missed — now read from edit segments.
- Writer: audio timestamp gaps could be closed up — new track part per discontinuity.
- UI: dark-mode filled-button contrast (2.1–3.1:1) — new fill tokens; largest-text mid-word breaks — adaptive rows; truncated titles; hidden search field; unbuilt Pro features removed from marketing copy.
- Resource governance only at Start — now evaluated every second during capture with protected stop.
