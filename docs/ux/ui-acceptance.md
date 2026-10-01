# UX01–UX18 non-device acceptance (roadmap section 14.11)

**Build under test:** see "Evidence run" below. **Simulator:** iPhone 17 Pro, iOS 27.0 (xcode-27 runner).
**Physical follow-ups:** all `DEFERRED_TO_P14`. A screenshot proves appearance only; it does not prove capture or hardware behaviour.
**Independent review:** INDEPENDENT_REVIEW_PENDING — results below are author-side evidence.

Status keys: `PASS (sim)` = automated simulator/static evidence passed; `PARTIAL` = some required evidence missing; `PENDING` = not yet executed; `FAIL` = executed and failed.

| ID | Non-device evidence | Source of evidence | Status |
|---|---|---|---|
| UX01 | Tokens/components on all screens; light + dark screenshots of normal and critical states | design-system.md; screenshots 01–25; `testDarkAppearanceScreens` | PENDING |
| UX02 | Smallest/largest simulator layouts; safe areas; no clipped primary action | Requires a second simulator size run (iPhone 16e / SE) | PENDING |
| UX03 | Largest accessibility text keeps Stop available | `testLargestTextDarkModeKeepsStop` | PENDING |
| UX04 | Measured contrast; colour-independent labels | `docs/ux/contrast-report.md` (32/32 pairs pass); StatusPill = colour+icon+text | PASS (static) |
| UX05 | Hit areas ≥ 44 pt, primary 56 pt; visible alternatives to swipe | Tokens + `performAccessibilityAudit(.hitRegion)`; context menus + accessibility actions mirror swipes | PENDING |
| UX06 | Unknown/stale/limited/partial/recovered produce exact truthful labels; resumed audio keeps the gap | Core `PolicyTests.truthfulCopy`, `HealthVerifierTests.resumeKeepsGap`, app `CopyAndSettingsTests`, `testGapNoticePersistsAfterResume` | PENDING |
| UX07 | Repeated Start/Stop, tab changes, sheet dismissal don't duplicate sessions | Core `doubleRecordAndStop`, `testTabSwitchRestoresSessionAndStripStops` | PENDING |
| UX08 | Accessibility hierarchy/labels/values; timer not announced each tick | `testAccessibilityAudit`; announcements only on gap/stop | PENDING |
| UX09 | Reduce Motion / Transparency / Increase Contrast keep content clear | High-contrast colour variants measured; Reduce Motion disables pulse and transitions | PARTIAL (no simulator setting run yet) |
| UX10 | Cancel/deny/unsupported have next actions; native picker not imitated | `testPickerCancelledDeniedUnsupported` | PENDING |
| UX11 | Empty, no-results, loading, error, timeout, recovery states actionable | `testEmptyLibrary`, `testLargeLibrarySearchFilter`, core `finalizeHangs`, recovery tests | PENDING |
| UX12 | 1,000-item library search/sort/filter without media decoding | Core `largeLibrary`; `testLargeLibrarySearchFilter` | PENDING |
| UX13 | Real fixture waveform/markers/seek/export agree with saved media | `testPlayerWithRealFixtureMedia`; media tests | PENDING |
| UX14 | Long names, Unicode, locale formatting, RTL readiness | Seed titles incl. Urdu and long titles; locale format styles | PARTIAL (no RTL pseudo-language run yet) |
| UX15 | Declined/offline/restored purchase never blocks core | Core `entitlement`; `testProScreenNeverBlocksCore` | PENDING |
| UX16 | Injected load disables optional visuals; Stop/fault deadlines kept | `ResourceGovernor` tests; meter gated by `allowsOptionalVisuals` | PARTIAL (no UI load-injection run yet) |
| UX17 | Active-session navigation and Live Activity stale/interrupted states | Strip test; `LiveActivityController` stale date 45 s | PARTIAL (Live Activity not rendered in tests) |
| UX18 | Unassisted task by an independent reviewer in the simulator | Requires independent reviewer | PENDING (needs reviewer) |

## Evidence run

_To be filled from the CI run that produces the screenshot artifact._
