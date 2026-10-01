# Progress

**Next action:** confirm the latest CI run on `phase/p08-app-build` is green, merge to `main`, then hand off to the independent reviewer (B03). After acceptance and owner signing access (B01): P13 TestFlight, then P14 physical testing.

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
| P13 Signing / TestFlight (M2) | BLOCKED — owner access (B01) | — | — | — |
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
