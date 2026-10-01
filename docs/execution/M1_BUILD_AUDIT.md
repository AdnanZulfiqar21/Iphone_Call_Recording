# P12 complete-build audit (author-side)

**Status:** IMPLEMENTATION COMPLETE and non-device verification executed. **M1 (APPLICATION_BUILD_COMPLETE) is not yet accepted**: the roadmap requires independent review of the exact SHA (section 24), recorded as `INDEPENDENT_REVIEW_PENDING`. `DEVICE_EVIDENCE_PENDING` for every runtime capture claim.

## Scope checklist (roadmap P00–P12)

| Requirement | Implementation | Evidence |
|---|---|---|
| Native capture, explicit start, genuine picker | `ScreenCaptureKitEngine` (iOS 27) | SDK_COMPILED (iOS 27 device SDK) |
| Single session / single writer / generation isolation | `SessionStateMachine`, `SessionController`, writer lease | T01, T04, T21, property test |
| Truthful source status, unknown never green | `HealthVerifier`, `StatusPresenter`, `StatusCopy` | T03, T05–T13, T15, UX06 tests |
| Bounded ingress, no silent loss | `BoundedIngress`, pipeline drain/abandon | T17, T18, T20 |
| Checkpointed recoverable writing | `SegmentedTrackWriter` + `SegmentCommitter` | iOS-hosted writer tests; T24 |
| Bounded stop, finalization deadline, recovery preserved | Deadlines in controller | T20, T21 |
| BASIC + resumable FULL validation | `RecordingValidator` | T06 file-hole, epoch, end-to-end tests |
| Store, deletion transaction, migrations, quarantine | `RecordingStore`, `RecoveryManager` | T23–T30 |
| Diagnostics without content; resource governance during capture | `DiagnosticsLog`, `ResourceGovernor` in tick | T35, T36, low-storage protected stop, UX16 UI test |
| Setup, permissions, privacy, consent notice, app lock, privacy shield | Welcome, SetupGuide, ConsentReminder, AppLock, PrivacyShield | UI tests; release audit (usage strings, background modes, privacy manifest) |
| Library, search/sort/filter, player, bookmarks, gap markers, export | LibraryView, PlayerView, ExportSheet, WaveformService | UX12, UX13 UI tests |
| Purchase, restore, entitlement isolation | `EntitlementService`, ProView, `.storekit` | T33, UX15 |
| Premium UX/UI: design system, light/dark, accessibility | `DesignSystem/`, asset tokens | Contrast 32/32, accessibility audit, AX-size, RTL, small/large layouts, screenshots |
| Live Activity with stale state | `LiveActivityController`, widget extension | Compiles and embeds; rendering not automatable in CI (UX17 partial) |
| No test doubles in shipping build | DEBUG-only synthetic engine/fixtures | Release binary audit PASS |
| No placeholders / TODOs on production paths | — | Source sweep: none found |

## Known limitations (carried to review/P14)

1. Remote call audio (WhatsApp/FaceTime) delivery through `SCStreamOutputType.audio` is UNTESTED; UI keeps it "Unconfirmed" until media arrives.
2. `AVAudioSession(.playAndRecord, .mixWithOthers)` effect on a live call is unmeasured (P14).
3. Live Activity rendering and lock-screen staleness are not covered by automated UI tests.
4. Bundle ID and Pro product ID are provisional (B01, B04).
5. Simulator capture uses the synthetic adapter; it proves the app/writer/validator path only.
