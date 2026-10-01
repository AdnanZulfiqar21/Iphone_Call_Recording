# Roadmap review — v2.1 → v2.2

**Date:** 1 October 2026
**Reviewed file:** `docs/roadmap/CallCapture_Development_Roadmap_v2_Build_First.md` (v2.1 baseline, SHA-256 `ddc86299c14da6bdfc63d7c55c5fc0d082909b59cfb94d5c66934588c847e2ad`)
**Reviewer:** Claude (author-side review). This is **not** an independent review; Cursor review remains `INDEPENDENT_REVIEW_PENDING`.

## Summary

v2.1 is a strong, internally consistent plan. Its integrity rules, truth-state model, fault matrix (T01–T36) and UX gate (UX01–UX18) are sound and were kept unchanged. The review found 2 factual errors and 14 gaps. None needed a requirement to be weakened; every change adds detail or corrects a reference.

| Severity | Count | IDs |
|---|---|---|
| Error (incorrect content) | 2 | R01, R02 |
| High-impact gap (could block build or App Store) | 5 | R03, R04, R05, R06, R10 |
| Medium gap (slows execution or risks rework) | 7 | R07, R08, R09, R11, R13, R14, R15 |
| Low / consistency | 2 | R12, R16 |

## Findings

### R01 — Wrong repository reference (Error)
v2.1 named `Adnan-Zulfiqar/Iphone_Call_Recorder`. The project repository is `AdnanZulfiqar21/Iphone_Call_Recording`. Corrected in the header.

### R02 — Unverifiable source checksum (Error)
The recorded SHA-256 belongs to `CallCapture_Complete_Development_Roadmap(1).md`, which is not in the repository. Kept for history and added the checksum of the committed v2.1 baseline so future revisions can be traced.

### R03 — Only one capture path evaluated (High)
The plan depends entirely on ScreenCaptureKit on iOS 27+. ReplayKit's Broadcast Upload Extension (`RPBroadcastSampleHandler` + `RPSystemBroadcastPickerView`) is the long-standing public route for system-wide screen + app audio + microphone capture on iPhone. It has known constraints (separate process, tight memory limit, App Group hand-off) but it is the obvious comparison and fallback. v2.2 adds it as candidate B in section 3, P01 and the risk register, without claiming either path delivers remote VoIP audio.

### R04 — No target inventory (High)
Live Activity requires a widget extension target; a broadcast path requires an upload extension and App Group. These affect P00 project setup. Added section 5.1.

### R05 — No usage-description / capability list (High)
Missing Info.plist keys cause crashes at the first permission request or App Review rejection. Added section 13.1 with draft purpose strings and the export-compliance key.

### R06 — No recording-law guidance (High)
Call-recording consent law varies by jurisdiction. App Review (guideline 2.5.14) requires explicit consent and indication. Added section 13.2: a plain, non-blocking notice, no legal-advice claims, optional pre-start reminder.

### R07 — No dependency policy (Medium)
Added rule 26 (no third-party analytics/tracking SDKs) and section 20.1 (dependency register, `.gitignore`, secret scanning).

### R08 — Test tooling undefined (Medium)
Added section 18.1: Swift Testing / XCUITest, injected clocks, script-generated fixtures with independently written expected results, accessibility audits, StoreKit test sessions.

### R09 — CI cost path for Windows workstation (Medium)
The repository is public, so standard GitHub-hosted macOS runners can be used without per-minute charges (terms to be rechecked). Added to section 20 with concurrency/cost rules.

### R10 — App Store submission items missing (High)
Added name/trademark check, version/build scheme, export compliance, age rating, TestFlight notes (P13), privacy-policy/support URLs and App Review notes (P16), and matching checklist lines (section 25).

### R11 — Crash diagnosis without analytics (Medium)
Added optional on-device MetricKit diagnostics, included only in user-exported reports (P07).

### R12 — Storage management (Low)
Added a Settings storage view: usage breakdown, cache clearing, optional age reminders, never automatic deletion (section 14.3, P09).

### R13 — UX tokens only described in words (Medium)
Added section 14.12: proposed light/dark colour values, type ramp, SF Symbols set, ASCII wireframes, six key journeys, copy-deck rules and haptics map. Values are proposals that P02 must contrast-test before freezing. A clickable visual mockup is in `docs/ux/mockups/callcapture-ui-mockup.html`.

### R14 — Supported-device list undefined (Medium)
Added to section 3: P01 records every iPhone that can run the chosen minimum iOS.

### R15 — Execution records undefined (Medium)
Added section 24.1 defining `docs/execution/PROGRESS.md`, `BLOCKERS.md`, `RESUME_STATE.md` and `docs/reviews/CURSOR_REVIEW_INDEX.md`, with four separate status columns.

### R16 — Free tier list incomplete (Low)
Section 21 now lists storage view, Restore Purchases, privacy information and diagnostics export as free, matching section 14.3.

## Not changed (deliberately)

- Phase order, milestones M1–M5 and the "complete build first, physical iPhone testing after" sequence.
- All integrity rules 1–25, truth states, acceptance profile (section 15), T01–T36 and UX01–UX18.
- Platform claims about iOS 27 ScreenCaptureKit and the cited 2026 sources were not re-verified in this review; section 27 already requires rechecking them at implementation time.
