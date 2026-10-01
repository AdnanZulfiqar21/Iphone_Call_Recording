# Independent review index

Cursor (independent reviewer) has not been available in this execution session. Every phase is therefore recorded as **INDEPENDENT_REVIEW_PENDING**. Author-side checks below are self-review and are **not** independent acceptance (`docs/execution/AUTONOMOUS_BUILD_AUTHORIZATION.md`).

| Phase | Scope | Reviewed SHA | Independent review | Author-side checks | Open findings |
|---|---|---|---|---|---|
| Roadmap v2.2 | Gap review of v2.1 | c99a10c | INDEPENDENT_REVIEW_PENDING | `docs/roadmap/ROADMAP_REVIEW_v2.2.md` | — |
| P00–P12 | See `docs/execution/PROGRESS.md` | (see PROGRESS) | INDEPENDENT_REVIEW_PENDING | Tests listed per phase | See BLOCKERS |

## Review handoff template (roadmap section 24)

```text
Phase / scope:
Starting commit:
Final commit:
Implemented requirements:
Tests actually run and results:
Toolchain / configuration:
Evidence level:
Physical evidence: DEFERRED_TO_P14 (for P00–P12)
Known limitations and unresolved findings:
Independent review result / reviewed SHA:
UX/UI evidence / applicable UX01–UX18 results:
Acceptance status:
Next phase:
```

## Suggested focus for the independent reviewer

1. `Packages/CallCaptureCore/Sources/CallCaptureCore/Session/` — lifecycle, generation isolation, single-writer lease, deadline handling.
2. `Health/HealthVerifier.swift` and `AnomalyLedger.swift` — no path from unknown/stale to a passing claim; gaps never erased.
3. `Recovery/` and `Store/RecordingStore.swift` — deletion transaction, quarantine, rule 20 (only recoverable copy).
4. `CallCaptureMedia/SegmentedTrackWriter.swift` — checkpoint semantics, lock ordering, epoch handling.
5. `CallCaptureMedia/ScreenCaptureKitEngine.swift` — audio session options and their possible effect on a live call (P14 risk).
6. App copy (`App/Sources/DesignSystem/StatusCopy.swift`) against the evidence-to-copy table.
