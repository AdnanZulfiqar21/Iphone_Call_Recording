# UX01–UX18 non-device acceptance (roadmap section 14.11)

**Build under test:** see "Evidence run" below. **Simulator:** iPhone 17 Pro, iOS 27.0 (xcode-27 runner).
**Physical follow-ups:** all `DEFERRED_TO_P14`. A screenshot proves appearance only; it does not prove capture or hardware behaviour.
**Independent review:** INDEPENDENT_REVIEW_PENDING — results below are author-side evidence.

Status keys: `PASS (sim)` = automated simulator/static evidence passed; `PARTIAL` = some required evidence missing; `PENDING` = not yet executed; `FAIL` = executed and failed.

| ID | Non-device evidence | Source of evidence | Status |
|---|---|---|---|
| UX01 | Tokens/components on all screens; light + dark screenshots of normal and critical states | design-system.md; screenshots 01–25 (light) and 19–23 (dark) in `docs/ux/evidence/run-36827394334/`; `testDarkAppearanceScreens` passed | PASS (sim) |
| UX02 | Smallest/largest simulator layouts; safe areas; no clipped primary action | Record/Stop, onboarding and AX-text flows passed on iPhone 17e (smallest iOS 27 simulator available) and iPhone 17 Pro; largest device not yet run | PARTIAL |
| UX03 | Largest accessibility text keeps Stop available | `testLargestTextDarkModeKeepsStop` passed (17 Pro and 17e). Screenshot 19 on 17e showed mid-word breaks in source rows → fixed with adaptive vertical rows; re-verification pending | PARTIAL (fix pending re-run) |
| UX04 | Measured contrast; colour-independent labels | `docs/ux/contrast-report.md` (32/32 pairs pass); StatusPill = colour+icon+text | PASS (static) |
| UX05 | Hit areas ≥ 44 pt, primary 56 pt; visible alternatives to swipe | `performAccessibilityAudit(.hitRegion)` passed on Record, Recordings, Settings; context menus + accessibility actions mirror swipe actions | PASS (sim) |
| UX06 | Unknown/stale/limited/partial/recovered produce exact truthful labels; resumed audio keeps the gap | Core `truthfulCopy`, `resumeKeepsGap`; app `CopyAndSettingsTests` (5/5); UI `testGapNoticePersistsAfterResume` passed (screens 07, 08) | PASS (sim) |
| UX07 | Repeated Start/Stop, tab changes, sheet dismissal don't duplicate sessions | Core `doubleRecordAndStop` + property test; UI `testTabSwitchRestoresSessionAndStripStops` passed (exactly one recording) | PASS (sim) |
| UX08 | Accessibility hierarchy/labels/values; timer not announced each tick | `testAccessibilityAudit` passed (dynamicType, elementDetection, hitRegion, sufficientElementDescription); announcements only on new gap/stop | PASS (sim, automated audit only) |
| UX09 | Reduce Motion / Transparency / Increase Contrast keep content clear | High-contrast colour variants measured; Reduce Motion disables pulse and transitions | PARTIAL (no simulator setting run yet) |
| UX10 | Cancel/deny/unsupported have next actions; native picker not imitated | `testPickerCancelledDeniedUnsupported` passed (screens 09–11) | PASS (sim) |
| UX11 | Empty, no-results, loading, error, timeout, recovery states actionable | `testEmptyLibrary`, search no-results, core `finalizeHangs` and recovery suites passed; recovery banner not yet screenshot-verified | PARTIAL |
| UX12 | 1,000-item library search/sort/filter without media decoding | Core `largeLibrary` (<2 s); UI `testLargeLibrarySearchFilter` passed with 1,000 seeded rows (screens 13–15) | PASS (sim) |
| UX13 | Real fixture waveform/markers/seek/export agree with saved media | `testPlayerWithRealFixtureMedia` passed: real master with gap marker 00:06–00:09, seek, play, export sheet (screens 17–18). Waveform bars not visible in screenshot 17 → under investigation | PARTIAL |
| UX14 | Long names, Unicode, locale formatting, RTL readiness | Seed titles incl. Urdu and long titles; locale format styles | PARTIAL (no RTL pseudo-language run yet) |
| UX15 | Declined/offline/restored purchase never blocks core | Core `entitlement`; UI `testProScreenNeverBlocksCore` passed (screen 24) | PASS (sim) |
| UX16 | Injected load disables optional visuals; Stop/fault deadlines kept | `ResourceGovernor` tests; meter gated by `allowsOptionalVisuals` | PARTIAL (no UI load-injection run yet) |
| UX17 | Active-session navigation and Live Activity stale/interrupted states | Strip test; `LiveActivityController` stale date 45 s | PARTIAL (Live Activity not rendered in tests) |
| UX18 | Unassisted task by an independent reviewer in the simulator | Requires independent reviewer | PENDING (needs reviewer) |

## Evidence run

Run [36827394334](https://github.com/AdnanZulfiqar21/Iphone_Call_Recording/actions/runs/36827394334) on `xcode-27` (Xcode 27.0, iOS 27.0 simulator): 13/13 UI tests passed on iPhone 17 Pro; 3/3 layout-sensitive UI tests passed on iPhone 17e; 10/11 app-hosted unit/media tests passed (T06 file-hole detection failed → validator fix in the next run). Screenshots: `docs/ux/evidence/run-36827394334/` (downscaled 50%).
