# UX01–UX18 non-device acceptance (roadmap section 14.11)

**Build under test:** see "Evidence run" below. **Simulator:** iPhone 17 Pro, iOS 27.0 (xcode-27 runner).
**Physical follow-ups:** all `DEFERRED_TO_P14`. A screenshot proves appearance only; it does not prove capture or hardware behaviour.
**Independent review:** INDEPENDENT_REVIEW_PENDING — results below are author-side evidence.

Status keys: `PASS (sim)` = automated simulator/static evidence passed; `PARTIAL` = some required evidence missing; `PENDING` = not yet executed; `FAIL` = executed and failed.

| ID | Non-device evidence | Source of evidence | Status |
|---|---|---|---|
| UX01 | Tokens/components on all screens; light + dark screenshots of normal and critical states | design-system.md; screenshots 01–25 (light) and 19–23 (dark) in `docs/ux/evidence/run-36839880635/`; `testDarkAppearanceScreens` passed | PASS (sim) |
| UX02 | Smallest/largest simulator layouts; safe areas; no clipped primary action | Record/Stop, onboarding and AX-text flows passed on iPhone 17e (smallest iOS 27 simulator) and iPhone 18 Pro Max (largest), plus iPhone 17 Pro (screens *-iphone17e, *-iphone18promax) | PASS (sim) |
| UX03 | Largest accessibility text keeps Stop available | `testLargestTextDarkModeKeepsStop` passed on 3 sizes; adaptive rows stack vertically with no mid-word breaks (screen 19 on 17e, run 36839880635) | PASS (sim) |
| UX04 | Measured contrast; colour-independent labels | `docs/ux/contrast-report.md` (32/32 pairs pass); StatusPill = colour+icon+text | PASS (static) |
| UX05 | Hit areas ≥ 44 pt, primary 56 pt; visible alternatives to swipe | `performAccessibilityAudit(.hitRegion)` passed on Record, Recordings, Settings; context menus + accessibility actions mirror swipe actions | PASS (sim) |
| UX06 | Unknown/stale/limited/partial/recovered produce exact truthful labels; resumed audio keeps the gap | Core `truthfulCopy`, `resumeKeepsGap`; app `CopyAndSettingsTests` (5/5); UI `testGapNoticePersistsAfterResume` passed (screens 07, 08) | PASS (sim) |
| UX07 | Repeated Start/Stop, tab changes, sheet dismissal don't duplicate sessions | Core `doubleRecordAndStop` + property test; UI `testTabSwitchRestoresSessionAndStripStops` passed (exactly one recording) | PASS (sim) |
| UX08 | Accessibility hierarchy/labels/values; timer not announced each tick | `testAccessibilityAudit` passed (dynamicType, elementDetection, hitRegion, sufficientElementDescription); announcements only on new gap/stop | PASS (sim, automated audit only) |
| UX09 | Reduce Motion / Transparency / Increase Contrast keep content clear | Increase Contrast enabled via `simctl ui` and two flows re-run (screens *-increased-contrast); HC colour variants measured 32/32. Reduce Motion/Transparency toggles not automatable via simctl — code paths disable pulse/transitions | PARTIAL (Reduce Motion pending reviewer/device) |
| UX10 | Cancel/deny/unsupported have next actions; native picker not imitated | `testPickerCancelledDeniedUnsupported` passed (screens 09–11) | PASS (sim) |
| UX11 | Empty, no-results, loading, error, timeout, recovery states actionable | `testEmptyLibrary`, search no-results, core `finalizeHangs` and recovery suites passed; recovery banner not yet screenshot-verified | PARTIAL |
| UX12 | 1,000-item library search/sort/filter without media decoding | Core `largeLibrary` (<2 s); UI `testLargeLibrarySearchFilter` passed with 1,000 seeded rows (screens 13–15) | PASS (sim) |
| UX13 | Real fixture waveform/markers/seek/export agree with saved media | `testPlayerWithRealFixtureMedia` waits for a waveform built from the saved media; gap drawn as gap (screen 17); markers, seek, play, export sheet | PASS (sim) |
| UX14 | Long names, Unicode, locale formatting, RTL readiness | Long and Urdu titles wrap fully; pseudo-RTL run mirrors layout (screens 27–28); locale format styles | PASS (sim, English only shipped) |
| UX15 | Declined/offline/restored purchase never blocks core | Core `entitlement`; UI `testProScreenNeverBlocksCore` passed (screen 24) | PASS (sim) |
| UX16 | Injected load disables optional visuals; Stop/fault deadlines kept | `-UITestThermal fair` → governor CONSERVE → meter hidden with notice, Stop works (screen 26); core low-storage protected stop test | PASS (sim) |
| UX17 | Active-session navigation and Live Activity stale/interrupted states | Strip test; `LiveActivityController` stale date 45 s | PARTIAL (Live Activity not rendered in tests) |
| UX18 | Unassisted task by an independent reviewer in the simulator | Requires independent reviewer | PENDING (needs reviewer) |

## Evidence run

Run [36839880635](https://github.com/AdnanZulfiqar21/Iphone_Call_Recording/actions/runs/36839880635) at `835c35d` on `xcode-27` (Xcode 27.0, iOS 27.0 simulators) — all jobs green:
15/15 UI tests on iPhone 17 Pro; 3/3 layout tests on iPhone 17e and iPhone 18 Pro Max; 2/2 flows with Increase Contrast; 11/11 app-hosted Swift Testing tests (6 AVFoundation pipeline tests). Screenshots (downscaled 50%): `docs/ux/evidence/run-36839880635/`.
