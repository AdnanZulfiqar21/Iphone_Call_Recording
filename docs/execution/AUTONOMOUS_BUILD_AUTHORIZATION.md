# Autonomous build authorization

**Recorded:** 1 October 2026
**Given by:** Repository owner (AdnanZulfiqar21), directly in the development session
**Applies to:** `docs/roadmap/CallCapture_Development_Roadmap_v2_Build_First.md` (v2.2), phases P00–P12, then P13–P16 where access allows

## What the owner authorized

1. Implement the complete native Swift/SwiftUI application (P00–P12) in roadmap order, including recording, storage, recovery, validation, privacy, playback, export, purchase and premium UX/UI.
2. Create and edit project files, install necessary dependencies, create branches, commit and push normal updates (no force pushes).
3. Create, push and run GitHub Actions workflows on **standard** GitHub-hosted macOS runners for this public repository, with bounded artifact retention, timeouts and cancellation of superseded runs. Paid larger runners or billing changes still require asking the owner.
4. Continue from phase to phase without routine approval pauses.

## What this changes

This instruction **supersedes** earlier requirements to pause for phase-by-phase approval (roadmap section 24, step 6) or to wait for Cursor before continuing development (section 24, step 4).

- Routine phase approval does not block the next phase.
- Missing Cursor review does not block development. Each phase records `INDEPENDENT_REVIEW_PENDING` and a review handoff in `docs/reviews/CURSOR_REVIEW_INDEX.md`.
- Author-side checks are recorded as self-review and are **never** presented as independent acceptance.

## What this does not change

- Product requirements, recording-integrity rules (section 4), privacy requirements (section 13) and acceptance criteria (sections 14.11, 15, 18) stay intact. Failing checks are fixed, not weakened.
- Four statuses stay separate for every phase: implementation, build/test, independent review, physical-device validation.
- Physical iPhone testing happens only after the complete build (M1) and a TestFlight build (M2).
- Simulator or CI results are never presented as proof of real call-audio, Bluetooth or background-recording behaviour, for ScreenCaptureKit or any ReplayKit alternative.
- No invented results: an unexecuted build or test is reported as not run.

## When to stop and ask

Only when progress needs the owner's credentials, account access, hardware, a paid resource or an essential product decision. Blockers are recorded in `docs/execution/BLOCKERS.md` with exactly what is needed and what it blocks; unrelated work continues.
