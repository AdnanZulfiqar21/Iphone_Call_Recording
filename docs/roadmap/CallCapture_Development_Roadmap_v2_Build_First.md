# CallCapture — Complete Development Roadmap v2.2

**Delivery strategy:** Build the complete application first; perform physical iPhone testing afterwards.
**Date:** 1 October 2026 — Europe/London
**Revision:** v2.2 — gap/consistency review of v2.1 (see section 0). v2.1 made professional/premium UX/UI mandatory V1 scope, with implementation tasks and acceptance gates before the complete-build milestone.
**Platform:** Native iPhone application, Swift / SwiftUI
**Repository:** [AdnanZulfiqar21/Iphone_Call_Recording](https://github.com/AdnanZulfiqar21/Iphone_Call_Recording) (supersedes the earlier `Adnan-Zulfiqar/Iphone_Call_Recorder` reference)
**Roadmap path:** `docs/roadmap/CallCapture_Development_Roadmap_v2_Build_First.md`
**Development roles:** Claude implements; Cursor independently reviews.
**Document status:** Planning baseline. This document does not report an implemented or validated application.
**Source:** CallCapture_Complete_Development_Roadmap(1).md, plus both review rounds in the planning conversation. That source file is not stored in this repository; the v2.1 text committed as this file's first revision is the retained baseline.
**v2.1 baseline SHA-256 (as committed):** ddc86299c14da6bdfc63d7c55c5fc0d082909b59cfb94d5c66934588c847e2ad
**Original source SHA-256 (as recorded in v2.1, file not in repository):** 90ad8d458bcdb36c9ba93d5b51e136fadc8859c60b6334e39350752f8b1e4e29

## 0. Revision v2.2 — review findings and changes

v2.2 keeps every v2.1 requirement, rule and acceptance criterion. It corrects errors and fills gaps found during review; no existing requirement was weakened. Full reasoning is in `docs/roadmap/ROADMAP_REVIEW_v2.2.md`.

| ID | Type | Finding in v2.1 | Change in v2.2 |
|---|---|---|---|
| R01 | Error | Repository reference pointed to `Adnan-Zulfiqar/Iphone_Call_Recorder` | Corrected to `AdnanZulfiqar21/Iphone_Call_Recording` |
| R02 | Error | Source checksum referred to a file that is not in the repository and cannot be re-verified | Kept as historical record; added the checksum of the committed v2.1 baseline |
| R03 | Gap | Only ScreenCaptureKit (iOS 27+) was evaluated; ReplayKit Broadcast Upload Extension — the long-standing public system-wide capture path — was not assessed | Added to P01 evaluation, section 3 symbol table and risk register (section 23) |
| R04 | Gap | No project/target inventory: Live Activity needs a widget extension; a broadcast path would need an extension and App Group | Added section 5.1 target and bundle inventory |
| R05 | Gap | Info.plist usage-description and capability inventory not listed (microphone, Face ID, Photos add-only, Live Activities) | Added section 13.1 |
| R06 | Gap | No jurisdiction/consent-law guidance; call-recording laws differ (one-party vs all-party consent) | Added section 13.2 legal-notice requirements (no legal advice claims) |
| R07 | Gap | No third-party dependency, analytics or SDK policy | Added rule 26 and section 20.1 |
| R08 | Gap | Test frameworks, snapshot tooling and fixture generation not defined | Added section 18.1 |
| R09 | Gap | CI cost: public repositories receive free standard GitHub-hosted macOS minutes; this was not used in the plan for a Windows workstation | Added to section 20 |
| R10 | Gap | App Store items missing: export-compliance key, privacy-policy and support URLs, age rating, name/trademark check, version/build scheme | Added to P13, P16 and section 25 |
| R11 | Gap | No crash-diagnosis path without third-party analytics | Added on-device MetricKit/crash-diagnostic option to P07, user-shared only |
| R12 | Gap | Storage-usage view and retention controls missing from Settings | Added to section 14.3 Settings row and P09 |
| R13 | Gap | Section 14 defined tokens in words only; no proposed values, wireframes, copy deck or journey map | Added section 14.12 (proposed values, to be contrast-validated in P02/P10) and the reference mockup in `docs/ux/mockups/` |
| R14 | Gap | Supported-device list for the iOS 27 baseline not defined | Added to section 3 and section 19.4 |
| R15 | Gap | No execution-record files defined for recoverable progress | Added section 24.1 (`docs/execution/*`, `docs/reviews/*`) |
| R16 | Consistency | Section 14.3 says Settings shows "Restore Purchases", P11 lists restore, but section 21 Free/Pro list omitted where restore and storage settings live | Clarified in section 21 |

## 1. User instruction and delivery milestones

**Physical iPhone testing must begin only after the complete V1 application build is finished.**

Roman Urdu summary:

- Pehle poori application build hogi: recording implementation, saving, recovery, professional/premium UX/UI, playback, privacy aur commercial flows.
- Premium design mein consistent visual system, light/dark themes, polished screens, clear recording states, accessible controls aur restrained animations shamil honge; yeh sirf future polish nahi hai.
- Development ke dauran simulator, automated tests, synthetic media, SDK compilation aur independent code review use honge.
- Physical iPhone install, real calls aur on-device recording tests complete application build ke baad honge.
- Uske baad observed problems fix hongi, affected scenarios dobara test honge, phir release hogi.
- App build complete hone ka matlab WhatsApp/FaceTime recording support prove hona nahi. Woh status later physical tests se milega.

| Milestone | Meaning | Required evidence |
|---|---|---|
| M1 — APPLICATION_BUILD_COMPLETE | Complete scoped V1 implementation, premium UX/UI and non-device verification finished | P00–P12 accepted build/review evidence, including the section 14 UX gate |
| M2 — DEVICE_TEST_BUILD_AVAILABLE | Completed app signed, processed and available through TestFlight | P13 distribution evidence |
| M3 — DEVICE_VALIDATION_COMPLETE | Supported and unsupported scenarios identified on physical iPhones | P14 device reports |
| M4 — RELEASE_CANDIDATE_VALIDATED | Required fixes completed and affected scenarios retested | P15 evidence bound to the candidate build |
| M5 — RELEASE_READY | Supported scope, privacy, purchases and release package pass | P16 release checklist |

P00–P12 have **no physical-device prerequisite**. Missing physical evidence is recorded as DEVICE_EVIDENCE_PENDING and does not block those build phases. P13 uploads the completed application; the first required device installation and runtime tests occur in P14.

The original early P0B physical foundation gate and early P1 physical feasibility gate are replaced by this sequence. Their useful tests are retained in P14. Do not quietly reintroduce an early iPhone gate.

All phase completion states start as NOT_STARTED / NOT_REVALIDATED. Historical commits or earlier PASS statements are not current evidence until the exact repository state is examined.

## 2. Product scope and honest positioning

CallCapture helps a person deliberately capture available screen/audio, understand observable recording health, preserve recoverable media, and inspect the saved result.

Initial V1 scope:

1. Screen capture through supported public APIs.
2. Microphone and app/device audio capture when actually available.
3. Local recording library, playback, bookmarks, rename, delete and export.
4. Per-source health and missing-interval reports.
5. Recoverable writing, interruption handling and crash recovery.
6. Setup diagnostics, accessibility, protected storage and optional app lock.
7. A simple one-time Pro purchase architecture.
8. A professional native design system, polished end-to-end screens, light/dark appearance and complete empty/error/recovery states. Premium presentation is the baseline for every user, separate from the paid Pro entitlement.

**Candidate call scenarios** include WhatsApp and FaceTime audio/video calls with speaker and AirPods. These remain UNTESTED until P14. Ordinary cellular calls are not implicitly included; any such support needs an explicitly added test row and evidence.

Screen-only, screen-plus-available-audio and audio-only outputs are distinct contracts. Audio-only capture is enabled only if the selected public API path supports it; audio-only export from an existing recording is a separate derived-file feature.

Do not promise:

- Every call, every application, every route or both speakers.
- Hidden, automatic or silent recording.
- Recovery of audio that the operating system never supplied.
- Guaranteed uninterrupted operation after process termination.
- Legal authenticity or forensic certification.
- Device support inferred from simulator success.

Use scoped language such as “Screen capture active”, “Microphone audio detected”, “Conversation audio unconfirmed” and “File checks passed”. A historical device test does not establish the current session's health.

If P14 cannot demonstrate a useful call scenario, preserve the completed engineering work and record CALL_SCOPE_NOT_PROVEN. Enable only demonstrated capabilities; any substantial product repositioning is an explicit scope decision before release.

## 3. Platform baseline and evidence levels

As checked during the October 2026 review:

- Apple's iOS ScreenCaptureKit sample requires iOS 27 or later and uses the system content-sharing picker. [S1]
- Apple's sample includes SCRecordingOutput as a direct file-recording option. [S1]
- GitHub documents an xcode-27 preview runner; runner availability and installed Xcode versions must be checked when implementing CI. [S2]

Initial capture deployment baseline: **iOS 27+**, subject to the actual compiled symbol-availability table in P01. Earlier-iOS capture support is outside the initial implementation scope. Do not substitute private APIs or presume that a macOS API behaves identically on iOS.

| Evidence level | What it establishes | What it cannot establish |
|---|---|---|
| DOCUMENTED | A public source describes an API or rule | Behaviour of this app on this iPhone |
| SDK_COMPILED | Native implementation compiles/links against the selected SDK | Runtime capture permissions or call audio |
| SYNTHETIC_TESTED | Logic handles controlled inputs and failures | Real microphone, Bluetooth or background behaviour |
| SIMULATOR_TESTED | UI/integration flows work in the simulator | Real-device recording compatibility |
| DEVICE_OBSERVED | A specific scenario worked or failed in physical testing | Universal support or current-session health |
| RELEASE_VALIDATED | The release scope passes its declared device matrix | A guarantee against all future failures |

Maintain a symbol table containing framework, symbol, SDK availability, minimum OS, background/permission requirements, fallback behaviour and source date.

**Capture path candidates (v2.2).** P01 evaluates both public system-capture paths with the same requirement matrix before P03 commits to one production adapter:

| Candidate | Public API | Known constraints to verify in P01 | Status before P14 |
|---|---|---|---|
| A — ScreenCaptureKit on iOS | SCStream / content-sharing picker / SCRecordingOutput [S1] | iOS 27+ only; picker flow; background behaviour; per-symbol iOS availability | DOCUMENTED → SDK_COMPILED |
| B — ReplayKit Broadcast Upload Extension | RPBroadcastSampleHandler with RPSystemBroadcastPickerView [S19] | Separate extension process with a tight memory limit (historically about 50 MB — measure, do not assume); hand-off to the app through an App Group container; app-audio and microphone sample types | DOCUMENTED → SDK_COMPILED |

Neither candidate is assumed to deliver remote VoIP call audio; that remains UNTESTED until P14. If both compile, A remains the preferred V1 path when it meets the matrix on iOS 27; B is either a documented fallback or explicitly rejected with reasons. Do not ship two production writers for one session (rule 2).

**Supported devices.** The supported-device list is every iPhone model that can run the chosen minimum iOS version. P01 records that list from Apple's current compatibility page. Broad hardware claims still need the older/newer device evidence in section 19.4.

Keep version-dependent implementation decisions behind a small capture adapter. Recheck source links and SDK headers before adopting a platform claim.

## 4. Non-negotiable engineering rules

1. One active capture session and one authoritative session controller.
2. One active recording writer backend per capture session.
3. V1 schedules recovery remux, export/transcode and full validation outside active capture; there must not be a hidden competing writer.
4. Explicit user start and visible system/app indication are required.
5. System permission revocation and user Stop are authoritative.
6. Media timestamps use CoreMedia time; watchdogs use a monotonic clock.
7. User-facing dates are for display/audit, not media synchronization.
8. Session ID, generation and contract version bind every accepted event.
9. Queue limits apply at ingress, including retained buffers and pending tasks.
10. No AI, cloud requests, thumbnails, heavy validation or analytics on the capture-critical path.
11. Recording, ownership and basic playback/export work without an account.
12. Capture operation must not depend on internet access.
13. Received media, writer acceptance and persisted media are separate evidence.
14. Current health and cumulative recording completeness are separate.
15. A later healthy interval never removes an earlier missing interval.
16. Silence alone is not failure; sound alone does not identify two speakers.
17. Unknown or expired evidence never becomes a green success claim.
18. A playable file does not prove that all expected conversation was captured.
19. Finalized masters remain immutable; edits and exports are derived objects.
20. The only recoverable copy is never removed before a replacement is validated and committed.
21. User deletion must survive app termination and must not be undone by recovery.
22. File hashes detect mismatch; they do not establish legal authenticity.
23. Permission denial, user cancellation and unsupported configuration are distinct outcomes.
24. Basic warnings, retained recordings and recoverable media access are never paywalled.
25. No build-stage result is labelled as physical-device validation.
26. No third-party analytics, advertising, crash-reporting or tracking SDKs in V1. Any third-party dependency needs a recorded licence, purpose and privacy review (section 20.1).

The single-writer rule concerns media encoding/writing. Bounded journal, manifest and diagnostic writes required to protect capture are still permitted and must be included in the I/O budget.

## 5. Architecture and ownership

Keep the six original core modules. Add small supporting types/services only where ownership requires them.

| Module | Owns | Must not own |
|---|---|---|
| SessionController | Lifecycle, generation, capture contract, start/stop deadlines, event coordination | Sample encoding, UI-derived truth |
| CaptureEngine | Public capture APIs, picker events, samples, source/format observations | Storage policy, purchase checks, health verdicts |
| HealthVerifier | Fresh per-source evidence and cumulative anomaly evaluation | Media mutation, unsupported speaker attribution |
| MediaWriter | Selected writer backend, mixing policy, bounded inputs, acceptance receipts, checkpoint reports | Capture permission or commercial decisions |
| RecoveryManager | Journal reconciliation, repair attempts, migrations, quarantine and deletion awareness | Secret restarting of capture, unbounded retries |
| RecordingStore | Master/derived ownership, metadata transactions, deletion, export scheduling, backup/protection policy | Inventing capture health |

Supporting responsibilities:

- RecordingValidator: inspect saved media with explicit validation coverage.
- ResourceGovernor: enforce declared storage, memory, thermal and work budgets.
- Diagnostics: bounded, content-free technical events and user-triggered reports.
- CompatibilityStore: historical observations only.
- EntitlementService: purchase state, isolated from capture and owned-file access.
- UI and Live Activity projections: derive displays from authoritative state.

No second component independently decides that a session has successfully started, stopped or completed.

### 5.1 Targets, bundles and repository layout (v2.2)

| Target | Purpose | Notes |
|---|---|---|
| CallCapture (app) | SwiftUI application, core modules, UI | iPhone only; minimum iOS from P01 |
| CallCaptureCore (Swift package or framework) | SessionController, HealthVerifier, MediaWriter, RecoveryManager, RecordingStore, validator, governor | Platform-light so most logic tests run without UI |
| CallCaptureWidgets (widget extension) | Live Activity / Dynamic Island presentation | Reads projected state only; never the authority for capture liveness |
| CallCaptureBroadcast (upload extension) | Only if P01 selects candidate B | Shares an App Group container; bounded memory |
| CallCaptureTests / CallCaptureUITests | Unit, property, fixture and UI automation | Synthetic adapters live here or in a debug-only target |

Suggested layout: `App/`, `Packages/CallCaptureCore/`, `Extensions/`, `Tests/Fixtures/`, `docs/` (roadmap, ux, execution, reviews, platform), `scripts/`, `.github/workflows/`. Preview catalogues and fault-injection controls are compiled only into Debug/internal configurations.

## 6. Capture contracts and evidence model

### 6.1 CaptureContract

Before starting a session, freeze:

- Contract ID and schema version.
- Requested capture mode and user-selected scope.
- Required and optional sources: screen, microphone, app/device audio.
- Observable success conditions for each source.
- Allowed degradation, warning and protected-stop policy.
- Source-specific timing policy and resource limits.
- Required final validation coverage.
- Compatibility observation used for advice, if any.

Changing a required source creates a new contract segment and rechecks evidence. It must not retroactively redefine missing audio as optional.

A “both participants confirmed” contract cannot be enabled from volume levels, a mixed track or AI diarization alone. It requires an independently justified method and device validation. If no such method exists, expose that limitation.

### 6.2 EvidenceRecord

Represent stage observations with:

| Field group | Required contents |
|---|---|
| Identity | sessionID, generation, contractVersion, sourceID, formatEpoch |
| Media range | source sequence/range, PTS start/end, timebase mapping |
| Observation | monotonic observation time, evidence origin, expiry policy |
| Pipeline stage | received, accepted, checkpointed, validated |
| Outcome | passed, missing, inconclusive, failed, not required |
| Explanation | machine-readable reason code and relevant anomaly range |

Use range summaries rather than an indefinitely growing event per audio sample. Reject stale generations, malformed times and inconsistent stage mappings.

Encoding changes bytes, so capture-to-file reconciliation uses source identity, mapped time ranges and writer/segment receipts. Do not require compressed bytes to equal input PCM bytes.

### 6.3 SessionAnomalyLedger

Retain all known missing, inconclusive or damaged intervals, including startup/tail truncation and route-change gaps. Coalescing adjacent intervals must preserve their meaning and coverage.

Only new evidence that actually resolves an interval may change its classification. Returning to healthy capture is not such evidence.

Report required-source coverage separately. A long video track must not hide a shorter audio track or a hole in its middle.

## 7. Truth states and user-facing claims

Use separate models:

| Model | States / values |
|---|---|
| Lifecycle | IDLE, PREPARING, AWAITING_USER_SELECTION, STARTING, CAPTURING, STOPPING, FINALIZING, FINALIZED, CANCELLED, FAILED |
| CurrentSourceHealth | CHECKING, CHECKS_PASSING, LIMITED, UNAVAILABLE, UNKNOWN |
| CaptureCompleteness | NO_KNOWN_GAPS, PARTIAL, UNKNOWN |
| FileValidation | PENDING, BASIC_CHECKS_PASSED, FULL_CHECKS_PASSED, FAILED |
| HistoricalCompatibility | UNTESTED, OBSERVED_WORKING, OBSERVED_LIMITED, OBSERVED_FAILED, STALE |
| LibraryState | VALIDATING, AVAILABLE, RECOVERING, QUARANTINED, DELETE_PENDING |
| FinalOutcome | SAVED, SAVED_PARTIAL, RECOVERED, RECOVERED_PARTIAL, FAILED |

FINALIZED describes lifecycle completion, not complete conversation capture.

Do not use a single unqualified VERIFIED flag. Legacy terms must be mapped explicitly during migration.

Examples:

- “Recording — microphone audio detected.”
- “App audio unconfirmed.”
- “Recording resumed — an earlier 10-second audio gap remains.”
- “Saved — basic file checks passed.”
- “Saved with partial audio — 04:10–04:20 affected.”
- “Full media checks passed — participant completeness unconfirmed.”

Display verification scope, last observation age and affected ranges in details. Never turn UNKNOWN into a passing source simply because another source is healthy.

## 8. Lifecycle, interruptions and bounded stop

| Event | Required transition / action |
|---|---|
| Explicit Record | Freeze contract, check resources, show picker/permission flow |
| Picker cancelled or permission denied | CANCELLED or clear denied outcome; release resources |
| Picker selection accepted | Bind selection to generation, enter STARTING |
| First valid media arrives | Start the media timeline; independently evaluate required sources |
| Required source unconfirmed | Show checking/limited state; enforce selected timeout policy |
| Route, format or selection changes | Invalidate affected proof, create a new epoch, recheck |
| Stream/system stop | Stop ingesting new media; finish accepted data |
| User Stop | Acknowledge capture stop, freeze accepted cutoff, drain bounded queues |
| Drain complete | Finish encoder/writer, then validate and commit |
| Finalization deadline exceeded | Preserve recovery material; show pending recovery/failure honestly |
| Media services reset | Invalidate objects/evidence; safe close; require user action for restart |
| Process terminated | Recover persisted material at next launch; never imply capture continued |

Apple documents special handling for media-services reset and user-initiated restart. Apply the guidance to the audio objects actually owned by the app; do not assume ownership of another app's call audio session. [S3]

Record these boundaries separately: request time, permission/selection completion, first captured source time, first accepted source time, last accepted time and last recoverable range.

Stop is idempotent. A late callback cannot append to a finalized writer or mutate a new session. Accepted work up to the recorded cutoff must either finish or appear as an explicit loss; it must not silently disappear.

A timeout does not prove that a writer has closed. Keep its resource lease until closure/cancellation is confirmed; do not start another media writer, move its files or begin conflicting recovery while it may still write. The app can show a failed/pending-recovery session and remain usable for nonconflicting actions. If the backend cannot be safely closed, explain that new capture is temporarily unavailable instead of violating the single-writer invariant.

A user may wait in a permission picker. Do not count that time as recording or turn their deliberate delay into a capture fault.

## 9. Capture implementation, audio and format handling

Implement the production native capture path before M1, even though runtime device behaviour remains pending.

Capture callbacks validate session identity, inspect minimal metadata and enqueue within limits. They must not create an unbounded task per sample or retain an unbounded collection of pixel buffers.

Handle complete, idle, blank, suspended and stopped frame observations. An unchanged display can legitimately produce an idle status. Availability of each relevant symbol must be compiled for the target iOS SDK. [S4]

Audio handling must distinguish:

- No source provided by the platform.
- A provided source with no recent progress.
- Natural silence.
- Suspicious all-zero content.
- Clipping, discontinuity and malformed format.
- Audible content whose speaker/source identity is uncertain.

Do not activate a competing microphone engine or change routes merely to keep an indicator green. Starting, stopping and reconfiguring CallCapture must be evaluated for their effect on the original conversation in P14.

Freeze an explicit audio policy:

1. Preserve source provenance when available.
2. Map timestamps into one session timeline.
3. Rebuild converters safely when formats change.
4. Define channel mapping, gain/headroom and clipping reporting.
5. Avoid accidental duplication when the microphone also hears speaker output.
6. Treat noise reduction and enhancement as optional derived processing.
7. Validate playback/export mixing in independent players.

An audio route change can affect sample rate, channel count and buffer duration. Observe new formats rather than assuming every AirPods route uses the same format. [S5]

## 10. Writer selection, checkpoints and durable progress

### 10.1 Select one production backend

Evaluate SCRecordingOutput and a custom AVAssetWriter backend against the same deterministic fixtures and requirement matrix:

- Source/track control and observability.
- Start/stop callbacks and error handling.
- Audio/video synchronization.
- Recoverable output and checkpoint evidence.
- Memory/resource limits and format transitions.

Use SCRecordingOutput as a reference implementation where useful. Choose one production backend per session in P04. A native convenience writer must not be treated as proving durability it does not expose. The alternative can remain a development-only comparison.

### 10.2 Initial format policy

Prefer SDR, H.264 and AAC with a fixed output canvas/orientation policy and a conservative profile. Compile and document the controls actually available on iOS.

Frame-rate/bitrate/resolution adaptation is permitted only through tested APIs and defined writer transitions. If a setting cannot change safely within a file, use an explicit format epoch/segment transition or a protected stop. Never silently corrupt a container to maintain throughput.

### 10.3 Recoverable persistence

Choose and document a concrete fragmented/segmented format. Include initialization data, codec parameters, ordered media ranges, versioned manifests and checksums where required; a media fragment is not automatically a standalone playable file.

Checkpoint transaction:

1. Write media into a staging location.
2. Complete the selected segment/checkpoint operation.
3. Check the media range and required metadata.
4. Commit the journal/manifest transaction using documented filesystem semantics.
5. Advance only the evidence level actually established.

Distinguish WRITER_ACCEPTED, CHECKPOINT_COMMITTED and RECOVERY_VALIDATED. Retain the term “durable” only with a declared failure model. App-process kill, system reboot and sudden power loss are different failure models.

Track contiguous recoverable coverage per required source. A maximum timestamp is not proof of all earlier media.

Apple describes recoverable fragmented writing, and notes the risk before the first fragment is written. Include startup-fragment failures in the corpus. [S6] [S7]

Reserve storage for journals, close/finalization and a playable partial result. Converting fragments to a master may need extra space; if unavailable, retain a recoverable segmented recording instead of deleting its only copy.

## 11. Store, recovery, deletion and migration

Use an explicitly selected nonpurgeable app location, such as Application Support, with appropriate protection. The paths below are relative to that chosen root:

~~~text
CallCapture/
  Recordings/<sessionID>/
    master.mov
    metadata.json
    health.json
    validation.json
  Recovery/<sessionID>/
    initialization/
    segments/
    journal.json
    manifest.json
  Deletions/
    pending-deletions.json
~~~

The master extension follows the actual chosen format. Store regenerable caches separately. Temporary directories must not hold the only original or recoverable recording.

Recovery rules:

- Reconcile transaction state and media before attempting repair.
- Preserve useful prefixes/segments when the tail is damaged.
- Distinguish “not yet accessible because locked” from “corrupt”.
- Use bounded work, retry budgets and quarantine.
- Keep the app usable while a problematic item is quarantined.
- Do not start a new recording while conflicting V1 writer/recovery work is active.
- Persist progress so interrupted recovery is idempotent.

Deletion transaction:

1. Record a durable deletion intent.
2. Hide the item and cancel conflicting recovery/derived work.
3. Delete owned master, fragments, metadata and derived artifacts.
4. Reconcile partial deletion on relaunch.
5. Retire the deletion intent only when no owned recoverable copy can be resurrected.

Do not claim deletion of external exports, recipient copies or historical system backups.

Version every metadata, journal and manifest format. Test upgrade recovery, an interrupted migration and unknown future versions. Unsupported versions remain preserved/read-only or quarantined; never destructively guess their format.

## 12. Saved-file validation

### BASIC checks

Confirm readable container, declared tracks/formats, plausible durations, expected start/end boundaries and selected decode windows. Label the coverage as basic; successful spot checks do not establish full-file integrity.

### FULL checks

Inspect the required timeline, track/sample continuity, known anomaly ranges, tail and the declared full decoding coverage. Reconcile results against source/writer/checkpoint evidence, including internal holes and shorter audio.

Full validation is resumable, bounded and scheduled outside active recording. A person may access a saved item after basic checks while seeing “Full checks pending”. Do not freeze the app waiting for a long decode.

A validation failure preserves the original and routes the item to recovery/quarantine. Hashes identify the validated artifact and detect later changes; they are not a claim about the truth of the conversation.

Record validator version, file identity, validation coverage, detected ranges and result. A final file with missing required audio remains PARTIAL even if its remaining content decodes perfectly.

## 13. Privacy, permissions and consent

Implement the foundation in P02 and verify the complete policy in P10.

- Request only permissions needed for the user's selected operation.
- Explain full-display scope: other apps, notifications and sensitive content may enter a full-display recording.
- Do not describe full-display capture as automatically restricted to a particular call app.
- No automatic recording restart after relaunch, consent withdrawal or a reset that requires user action.
- Explain participant willingness/permission without claiming that the system picker proves remote participant consent.
- Maintain visible recording indication. Apple's App Review requirements include explicit consent and clear recording indication. [S8]
- Capture data is not uploaded by the app by default. Account creation is not required for core use.
- Diagnostics exclude recording content, transcripts, phone numbers, contacts and screen text by default.
- Redact sensitive previews and app-switcher snapshots where appropriate.
- Protect working files, masters, journals and derived copies according to their access requirements.
- Test protection at lock, unlock, new-segment creation while locked and post-reboot access in P14.
- An app lock is separate from encryption/file protection; a biometric prompt alone is not a complete storage policy.
- User-controlled sharing displays the destination and preserves the local master.

**Backup policy:** distinguish app-operated cloud sync, device/iCloud backups and user exports. Document the selected default and the consequences of losing a device. Do not exclude irreplaceable recordings silently, and do not promise that an exclusion flag makes backup impossible. Apple's backup guidance explicitly distinguishes these cases. [S9]

Apply resource/protection attributes after relevant file replacements and verify them. Failed access while protected data is unavailable must not trigger destructive recovery.

Prepare PrivacyInfo.xcprivacy, applicable required-reason declarations, usage descriptions, entitlement/background-mode inventory and accurate privacy labels. Revalidate current Apple requirements at distribution time.

### 13.1 Permission and capability inventory (v2.2)

Request each item only when its feature is used. Copy is short, specific and states what is not done.

| Key / capability | Needed for | Example purpose string (draft) |
|---|---|---|
| NSMicrophoneUsageDescription | Microphone audio in a recording | "CallCapture uses the microphone only while you are recording, to include your voice and nearby sound." |
| NSFaceIDUsageDescription | Optional app lock | "Face ID unlocks your recordings when App Lock is on." |
| NSPhotoLibraryAddUsageDescription | Optional add-only export to Photos | "Lets you save a copy of a recording to Photos. CallCapture cannot read your library." |
| NSSupportsLiveActivities | Live Activity | Not a permission prompt; users can still disable it |
| App Groups | Only with broadcast candidate B | Shared container for segments and state |
| Background modes | Only those P01 proves necessary and Apple permits for the chosen path | Each mode justified in the inventory; no audio mode used merely to stay alive |
| ITSAppUsesNonExemptEncryption = NO | Export compliance | Valid only while the app uses OS-provided encryption alone; recheck at P13 |

Screen capture permission is obtained only through the genuine system picker; the app never imitates it.

### 13.2 Recording-law and consent notice (v2.2)

Call-recording law differs by country and region (for example one-party versus all-party consent). CallCapture does not give legal advice and does not determine whether a recording is lawful.

- First launch and the setup guide include a short, plain notice: the person is responsible for informing participants and following local law.
- The notice links to an in-app help page; it is not a blocking legal quiz and does not claim the app makes recording lawful.
- Optional "Remind me to tell participants" toggle shows a brief pre-start reminder; default on, dismissible permanently in Settings.
- App Store description and screenshots must not encourage covert recording (section 13, [S8]).

## 14. Professional/premium UX/UI, recording experience and accessibility

### 14.1 Design outcome and V1 commitment

Deliver a calm, polished native iPhone application that helps a person start deliberately, understand what is being captured, stop confidently and find the saved result. Premium quality means coherent typography, spacing, visual hierarchy, responsive controls and carefully designed failure states across the whole app.

**This is required V1 work.** P12 cannot declare APPLICATION_BUILD_COMPLETE while required screens are placeholders or their design, accessibility and state handling are postponed. Before P14, design acceptance uses the simulator, synthetic fixtures, compiled native controls and independent review. Physical ergonomics and performance remain pending until the completed build reaches P14.

The visual baseline applies to free and paid users. “Premium UX/UI” describes product quality; it does not create a new purchase requirement for accessibility, clear warnings or owned recordings.

### 14.2 Visual direction and reusable design system

Use a restrained blue/indigo brand accent, neutral content surfaces, generous grouping and a distinctive recording control. Follow the system's native navigation and sheet behaviour. Prefer standard SwiftUI components, SF Symbols and semantic styles; keep custom design focused on recording status, the timeline and media organization.

Apple positions Liquid Glass around controls and navigation. Adopt its supported native treatment where appropriate, while keeping recording evidence, warnings and library content legible on stable surfaces. Custom glass is a small, availability-checked enhancement; it must preserve accessibility and resource limits. [S17]

The following are **CallCapture design decisions and acceptance targets**, not claims that Apple mandates this exact visual style:

| Token / component | V1 specification | Implementation rule |
|---|---|---|
| Appearance | System default, with Light and Dark overrides in Settings | Semantic asset colours; changing appearance never resets a session |
| Brand accent | One consistent blue/indigo accent for navigation and ordinary actions | Define named light/dark assets and validate contrast before freezing their exact values |
| Recording and severity | Red identifies the active recording/Stop action and destructive actions in their own context; amber identifies limitations | Pair colour with text and an icon; green is reserved for a narrowly supported passing check |
| Unknown evidence | Neutral styling plus “Checking”, “Unconfirmed” or “Status unavailable” | Unknown, stale and historically working states never inherit a current-success colour |
| Typography | Native text styles; default body uses the system body style, typically 17 pt; timer uses scalable monospaced digits | Dynamic Type throughout; important reasons wrap instead of shrinking or truncating |
| Spacing | Shared 4, 8, 12, 16, 24 and 32 pt scale | Use 16–20 pt content margins where layout allows; respect system safe areas and larger text reflow |
| Surfaces | Grouped neutral backgrounds, restrained separators and consistent content-card corners, initially 16 pt | Keep native control geometry native; use elevation only to explain layering |
| Controls | Primary Start/Stop targets at least 56 pt high; other interactive targets at least 44 × 44 pt | A large icon alone is not a usable target; include labels and accessible hit areas |
| Icons | Consistent SF Symbol weight/scale; label important or ambiguous actions | Decorative symbols are hidden from accessibility; actionable icons have meaningful names |
| Feedback | Consistent pressed, disabled, loading, success and failure presentations | Actual operation state drives feedback; disabled actions explain why when relevant |
| Brand assets | Finished app icon, matching launch appearance and restrained empty-state artwork | No artificial splash-screen delay; assets remain legible in supported appearances |

Apple's UI design guidance recommends a minimum 44 × 44 pt touch target. CallCapture uses the larger Start/Stop target above as its own product choice. [S16]

Create a small SwiftUI component layer: PrimaryActionButton, RecordingControl, SourceStatusRow, RecordingSummary, RecordingRow, InlineNotice, EmptyState, TimelineMarker and SettingsRow. Names can follow the repository's conventions. Components consume authoritative view state; they do not create independent capture logic or infer recording health from animation.

### 14.3 Information architecture and screen specifications

Use three primary tabs: **Record**, **Recordings** and **Settings**. Keep a stable navigation hierarchy and ordinary Back behaviour. Returning from another tab must restore the active session instead of starting a new one. Place an unobtrusive active-session strip on other app-owned screens, with a route back to the recording and a direct Stop action where the app controls the surface.

| Screen / flow | Visual and interaction specification | Required states and limits |
|---|---|---|
| First launch | Short value explanation, honest capability summary and a clear “Test My Setup” action; nonessential introduction can be skipped | No mandatory account, advance permission barrage or forced purchase before trying core features |
| Record dashboard | Clear page title, selected capture scope, compact setup/storage summary, one dominant Start action and recent recordings below | Unsupported and unknown scope are readable before starting; advanced configuration lives in a secondary sheet |
| Setup guide | Short ordered checks with a reason, current result and valid next action; optional sample playback where supported | Denial, cancellation and unavailable capture remain distinct; simulated checks are labelled |
| Active recording | Large timer, obvious labelled Stop control, concise source rows and a persistent earlier-gap notice; secondary details expand on demand | Waiting, starting, capturing, limited, interrupted and stopping are distinct; audio level animation never proves participant capture |
| Saving / recovery | Clear operation title, available result and bounded next step; progress is numeric only when measured | Explain when capture has ended but file saving continues; timed-out work moves to a preserved recovery state |
| Saved result | Outcome headline, duration, completeness and file-check summary, followed by Play and Share | Partial/recovered results retain their limitations; no celebratory full-success treatment for missing required media |
| Recordings library | Clean text-first rows with title, date, duration and outcome; local title search, recent/oldest sort and useful outcome filters | Separate first-use empty, no search results, loading, unavailable file and recoverable item states; long titles remain usable |
| Player / details | Large playback controls, elapsed/remaining time, accessible seeking, bookmarks and a labelled gap timeline | Use actual saved-media data; provide a text list for markers; any unavailable interval remains explicit |
| Export | Native share/Files flow with concise format and destination context; preserve the master | Show preparation, cancellation, failure and completion only when known; no false proof that a third-party destination finished its work |
| Settings / privacy / Pro | Native grouped settings for appearance, capture preferences, storage/backup, privacy, help and optional purchase | Show local price from StoreKit, Restore Purchases and a clear dismissal; core app access remains available |
| Storage (v2.2) | Total space used by recordings, recovery material and caches, with device free space; "Clear preview cache" action; optional reminder for recordings older than a chosen age | Never auto-deletes recordings; any clean-up lists the exact items and requires confirmation; recovery material is never offered as "cache" |

Library search in V1 covers local recording titles and existing metadata. Transcript search, generated summaries and cloud organization remain in section 22; they are not dependencies of this design work. Advanced organization can remain a Pro feature, but basic search, outcome visibility and owned-file access stay available.

Keep technical reason codes, buffer counters and codec details inside an optional diagnostics view. Main screens use plain language and one relevant next action. Do not add pause, automatic call detection or remote-speaker identification controls unless their behaviour is separately implemented, scoped and validated.

### 14.4 Guided setup and deliberate start

1. Show the selected recording scope and explain which audio is currently unconfirmed.
2. Request the necessary system permission only at the relevant step, with a short explanation.
3. Check storage and available capture controls; explain any block and offer its valid next action.
4. Offer “Test My Setup” and show the evidence level of its result.
5. Start only after the user's explicit action and the genuine system selection/permission flow.

The app does not redraw or imitate the system capture picker or permission dialog. Cancelling either returns to a calm, usable screen without a success badge or coercive repeated prompt.

“Setup checks passed” means the listed checks passed. It does not promise future remote-call audio. Before P14, simulator checks are explicitly simulated; starting each real session obtains fresh evidence.

For **Important Recording mode**, freeze stricter requirements before capture. Unsupported required sources block that contract with a reason. Inconclusive startup evidence stays “Checking” until its declared deadline. Preserve media already captured; stop safely or obtain an explicit user choice for a new limited contract. Retain the original unmet requirement in the report. Underlying protection and missing-audio warnings remain universal.

### 14.5 Active recording hierarchy and honest copy

The timer starts from actual capture time, never from waiting for the system picker. Its presence shows elapsed capture time, not that all expected audio is available. Separate current observations from accumulated completeness:

- **Primary:** recording lifecycle, elapsed time and an immediately identifiable Stop action.
- **Secondary:** each requested source's current observation and a readable freshness indicator; exact observation age can expand in details.
- **Persistent limitation:** any known missing interval remains visible even after the source resumes.
- **Context:** storage estimate with uncertainty, a short reason for the current limitation and a valid next step.

| Situation | Example user-facing text | Action / retained information |
|---|---|---|
| Waiting for selection | “Choose what to record” | Allow cancellation; elapsed capture time has not begun |
| Current microphone evidence only | “Microphone audio detected. Conversation audio unconfirmed.” | Show source details; do not label this “Both speakers recorded” |
| Checking required audio | “Checking audio availability…” | Apply the startup deadline and chosen contract policy |
| A source resumes after a gap | “Audio detected now. An earlier part is missing.” | Keep the missing-interval notice and timeline marker |
| Capture ended; writer finishing | “Recording stopped. Saving your file…” | Preserve work; distinguish capture off from file saved |
| Saved with a known loss | “Saved with missing sections” | Offer Play and “Review missing sections”; show affected source/time |
| Live status expired | “Status not updated” | Show last update and safe guidance; never imply it is still healthy |

Show only copy supported by the precise state and evidence. App-owned Stop is a direct action with immediate acknowledgement; it does not require a hold gesture, hidden swipe or pre-stop confirmation. Repeated taps remain idempotent. Deletion is a separate, clearly destructive interaction.

A full-display recording may continue after a call ends. Explain this once in setup and keep Stop easy to find. Do not promise automatic recognition of another app's call start/end without a supported, separately proved mechanism.

### 14.6 Library, playback and ownership experience

Make the most recent saved item easy to find after stopping. Preserve title edits, scroll position and selected filters through normal navigation. Provide visible menu alternatives to swipe actions; use a confirmation that identifies the item before permanent deletion. Do not display Undo unless the storage implementation can actually honour it.

In the player, calculate waveform/thumbnail assets from real saved media outside active capture and cache them with bounded storage. If no waveform is available, retain usable transport controls and say that the preview is unavailable. Gaps use labelled markers and accessible timestamp entries; never draw invented audio across a missing interval.

Selecting a gap or bookmark seeks to its defined position, with unavailable media explained rather than silently skipped. Finalized originals remain immutable. Basic playback, rename, delete, standard export and information required to understand a partial result remain usable without purchasing Pro.

Suspend ordinary in-app playback before beginning capture. Do not allow library previews or UI sounds to unexpectedly compete with a live call or contaminate a recording. Any later simultaneous-playback mode needs its own explicit scope and validation.

### 14.7 Motion, haptics and capture-safe performance

Use short native transitions and restrained feedback. Initial custom-motion target: approximately 180–250 ms for minor state changes; use a simple nonmoving alternative when Reduce Motion is enabled. Do not delay a state update, Stop acknowledgement or error message for an animation.

- A live level meter uses bounded, downsampled measurements from actual samples. It is labelled as input level, not “conversation verified”. Missing samples display unavailable/stale state; never generate a decorative waveform that looks like live evidence.
- Initial UI update budgets: elapsed-time text at 1 Hz and optional meters at no more than 10 Hz while visible. Significant lifecycle/fault changes bypass this cosmetic throttling.
- Keep media processing, waveform extraction, search indexing and export preparation away from the main UI thread and capture-critical callbacks.
- Reuse stable list identities and bounded caches. Large libraries must not decode every media file to render the list.
- Disable optional meter/decorative updates when not visible or under resource pressure; retain Stop, current warnings and truthful state.
- Use occasional optional haptics with visual/accessibility equivalents. No repeated warning buzz, celebratory recording sound or default sound effect during capture.

These are initial product budgets, not measured device performance. Verify synthetic behaviour during P08–P12 and profile actual responsiveness, memory, energy and haptic impact in P14. Reduce visual effects when measurements show contention; required recording protections take priority.

### 14.8 Accessibility and localization readiness

Plan for Dynamic Type, VoiceOver, Voice Control, Switch Control, Increase Contrast, Reduce Motion and reduced-transparency presentation. Apple's accessibility-testing guidance covers reflow, clear element names/states and assistive interaction; simulator and automated audits support the build gate, while physical assistive-technology validation stays in P14. [S18]

CallCapture acceptance targets:

- Every essential action and recording outcome is available without interpreting colour, sound, a waveform or a gesture alone.
- Body and status text target at least 4.5:1 contrast; meaningful non-text controls/indicators target 3:1 against adjacent colours. These are chosen design targets; measure actual light/dark and accessibility appearances.
- Support the largest accessibility text categories by reflowing content. Keep Stop available and permit readable vertical scrolling for secondary details.
- Provide logical focus order, descriptive labels, current values and meaningful state-change announcements. Do not announce every timer tick or meter fluctuation; urgent information must not steal focus from Stop.
- Status notices remain available until resolved or intentionally dismissed where appropriate. A transient toast is not the only place to learn of missing media.
- Use String Catalogs/localizable resources and locale-aware dates, durations, storage units and prices. Avoid sentence fragments assembled by concatenation.
- Test longer localized strings, Unicode recording titles, keyboard overlap and right-to-left layout readiness. Ship only languages actually translated and reviewed; Urdu or bilingual UI can be selected as release scope without assuming automatic translation quality.

### 14.9 Background, Live Activity and interruption presentation

Implement a Live Activity where supported, with readable elapsed/status information, last-update context and a clearly stale appearance. Use the same state/copy mapping as the in-app screen. ActivityKit stale-date semantics support freshness presentation; they are not the authority for capture liveness. [S10]

Do not rely on continuous custom animation or a fresh-looking timer to prove background health. Where a system-surface action is unsupported, provide an accurate route back to the app instead of a decorative nonworking control. Respect sensitive-preview settings on the lock screen and app switcher.

Test disabled Live Activities, Focus, notification denial, lock, accessory changes and system termination in P14. Until then these behaviours remain unvalidated. There is no guarantee of immediate alerts while the app cannot execute. Warnings must avoid recording contamination and provide controlled repetition with accessibility equivalents.

### 14.10 Required design deliverables and phase ownership

Keep the design specification and implementation in the repository so another developer can reproduce the intended UI. These are planned implementation artifacts, not files claimed to have been built by this roadmap revision.

| Phase | Required UX/UI deliverable | Acceptance evidence |
|---|---|---|
| P02 | docs/ux/design-system.md, screen inventory, navigation map and evidence-to-copy table; initial SwiftUI token/component definitions | Reviewed visual direction, state definitions and interface contracts |
| P08 | Complete Record/setup/active/saving/result/Settings UI, native navigation, accessibility semantics and Live Activity designs | Controller-connected simulator flows, component previews and state screenshots |
| P09 | Finished library/search/filter/player/export/recovery screens with real fixture media | End-to-end fixture tasks, long-title/empty/error cases and preserved ownership |
| P10 | Accessibility, privacy-preview and localized-layout review | Audit results, contrast records and resolved required-screen defects |
| P11 | Finished optional Pro, purchase, restore and offline-entitlement screens | Honest pricing/copy, clear dismissal and no safety/ownership paywall |
| P12 | docs/ux/ui-acceptance.md plus a versioned screenshot set under docs/ux/evidence/ | UX01–UX18 non-device gate reviewed at the exact M1 commit |
| P14–P16 | Physical interaction/accessibility/performance and target-user comprehension findings | Measured device reports, fixes and affected-screen retests |

Create an internal preview/component catalogue covering loading, empty, error, limited, stale and recovery states as well as the normal path. Keep fixture selectors and preview-only controls outside the shipping configuration. If a separate design tool is used, export the agreed specification into the repository; access to that tool must not be required to interpret the implementation.

### 14.11 Premium UX/UI acceptance gate

Every UX check below is required at M1 to the extent stated in the **Non-device acceptance** column. Record exact build, simulator size/OS, appearance, text setting, fixture and result. Physical checks remain **DEFERRED_TO_P14** until after M1 and P13. A screenshot proves appearance only; it cannot prove capture or hardware behaviour.

| ID | Non-device acceptance required before M1 | Follow-up after complete build |
|---|---|---|
| UX01 | All required screens use reviewed tokens/components and have complete light/dark normal and critical-state designs | Check appearance on supported physical displays |
| UX02 | Smallest/largest supported iPhone simulator layouts respect safe areas; no clipped actions, horizontal page scrolling or keyboard-covered primary action | Check actual reachability and supported orientation transitions |
| UX03 | Default and largest accessibility text sizes preserve readable status and an available Stop control | Complete large-text flows on a physical iPhone |
| UX04 | Measured text/control contrast meets section 14.8 targets; colour-independent labels distinguish every outcome | Check real-display legibility and accessibility settings |
| UX05 | Hit-area inspection meets 44 × 44 pt minimum and the larger primary-control target; core actions have visible alternatives to gestures | Assess one-handed use and accidental taps |
| UX06 | Unknown, stale, limited, partial and recovered fixtures produce exact truthful labels; resumed audio cannot erase a previous gap | Confirm observations and saved media agree in real scenarios |
| UX07 | Repeated Start/Stop, tab changes and sheet dismissal do not duplicate sessions, hide faults or lose user edits | Repeat during real capture and interruption |
| UX08 | Accessibility hierarchy, labels, values and focus order pass inspection/available simulator checks; timer updates do not flood announcements | Complete tasks with VoiceOver, Voice Control and Switch Control on device |
| UX09 | Reduced-motion/transparency and increased-contrast presentations retain content and action clarity | Verify actual system-setting changes and optional haptics |
| UX10 | Permission/selection cancellation, denial and unsupported setup have usable next actions; native picker is not imitated | Validate the genuine runtime permission/picker sequence |
| UX11 | Empty, no-results, loading, error, finalizing-timeout and recovery states are actionable; critical notices persist | Reproduce relevant storage/recovery failures on device |
| UX12 | Title search/sort/filter and stable list navigation work with a seeded 1,000-item metadata library without eagerly decoding media | Profile representative real library scrolling, memory and responsiveness |
| UX13 | Actual fixture waveform/markers, playback seeking, rename and export agree with saved media; unavailable previews have a fallback | Test headphones/speaker, native sharing and real files |
| UX14 | Long names, Unicode, longer localized strings, locale formatting and RTL layout readiness do not break core tasks | Review every shipped language and input method in release scope |
| UX15 | Core protection, accessibility and existing media remain usable through declined/offline/restored purchase states | Validate device purchase and ownership flows |
| UX16 | Injected load disables optional visuals while preserving state correctness and section 15 Stop/fault deadlines | Profile actual capture plus UI; fix measured resource/latency regressions |
| UX17 | Active-session navigation and Live Activity presentations include accurate stale and interrupted states | Test lock/background/disabled activity and system termination |
| UX18 | An independent reviewer can start, identify a limitation, stop, find the result and export from the simulator without developer coaching | P16 target-user task study confirms comprehension; record failures and fix misleading copy |

Freeze simulator screenshot fixtures and compare meaningful layout/state changes. Review intended changes instead of treating pixel equality as proof of usability. Automated checks supplement independent visual and interaction review.

### 14.12 UX/UI reference specification (v2.2)

This section turns section 14.2 into proposed starting values so P02 can begin immediately. **All values are proposals:** P02 freezes them only after measuring contrast in light, dark and Increase Contrast; P10 re-measures. A reference mockup of the screens below is kept at `docs/ux/mockups/callcapture-ui-mockup.html`; it is a design illustration with sample data, not evidence of implemented behaviour.

**Proposed colour tokens** (named asset colours; values are starting points to validate)

| Token | Light | Dark | Use |
|---|---|---|---|
| accent | #3B4FD8 (indigo) | #7C8CFF | Navigation, ordinary actions, links |
| recordRed | #D92D20 | #FF5A4E | Record/Stop control and active-recording indicator only |
| warningAmber | #B54708 (text) / #FDB022 (fill) | #FDB022 | Limited / partial / missing-section notices |
| passGreen | #067647 | #47CD89 | Only narrowly supported passing checks (e.g. "Basic file checks passed") |
| neutralUnknown | #667085 | #98A2B3 | Checking, Unconfirmed, Status not updated |
| surface / grouped background | system grouped background | system grouped background | Prefer semantic system colours |
| card | secondary system grouped background | same | Content cards, 16 pt corner radius |

**Type ramp** (native text styles; never fixed sizes)

| Role | Text style | Notes |
|---|---|---|
| Screen title | .largeTitle | Native navigation large title |
| Recording timer | .largeTitle, monospaced digits, semibold | Scales with Dynamic Type; never shrinks below readable size |
| Status headline | .title3 semibold | e.g. "Recording", "Saved with missing sections" |
| Source row | .body + .subheadline secondary | Name, current observation, freshness |
| Notice text | .callout | Wraps fully; never truncated |
| Metadata | .footnote secondary | Dates, sizes, durations (locale formatted) |

**Iconography (SF Symbols, one weight per context)**: record.circle, stop.fill, mic.fill / mic.slash, speaker.wave.2, rectangle.on.rectangle (screen), exclamationmark.triangle (limited), questionmark.circle (unknown), checkmark.seal (narrow pass), clock.arrow.circlepath (recovery), square.and.arrow.up (share), bookmark, waveform (only for real waveform data).

**Screen wireframes (reference)**

~~~text
RECORD (idle)                 ACTIVE RECORDING              SAVED RESULT
┌─────────────────────┐       ┌─────────────────────┐       ┌─────────────────────┐
│ Record          ⚙︎   │       │ ● Recording          │       │ Saved with missing  │
│ Scope: Full screen  │       │                      │       │ sections        ⚠︎   │
│ + microphone   [▾]  │       │      12:48           │       │ 32:05 · 214 MB      │
│ Setup: 3 of 4 ✓  >  │       │                      │       │ Audio missing       │
│ Storage: ~6 h free  │       │ Screen    Capturing  │       │ 04:10–04:20         │
│                     │       │ Mic       Detected   │       │ Basic file checks   │
│   ┌─────────────┐   │       │ App audio Unconfirmed│       │ passed              │
│   │ ● Start     │   │       │ ⚠︎ Earlier 10 s gap  │       │ [ ▶ Play ] [Share]  │
│   └─────────────┘   │       │   04:10–04:20     >  │       │ Review missing      │
│ Recent              │       │ ┌─────────────────┐  │       │ sections        >   │
│ Team call  32:05 ⚠︎ │       │ │ ■ Stop          │  │       └─────────────────────┘
│ Interview  18:22 ✓  │       │ └─────────────────┘  │
├─────────────────────┤       └─────────────────────┘
│ Record│Recordings│⚙︎ │
└─────────────────────┘
~~~

**Key user journeys** (each must complete without coaching — UX18)

1. First launch → value summary → legal/consent notice → Test My Setup → first recording.
2. Start → system picker → Checking → Recording → Stop → Saving → Saved result → Play.
3. Recording with a gap → persistent notice → Stop → "Saved with missing sections" → jump to gap in player.
4. Crash/termination → next launch → "1 recording can be recovered" → Recover → recovered result with its limitations.
5. Library → search title → open → rename → bookmark → Share/Files export.
6. Settings → Pro → localized price → purchase or dismiss → everything previously owned still works.

**Copy deck rules**: sentence case; one idea per line; state what is known, then what is not ("Microphone audio detected. App audio unconfirmed."); no "100%", "guaranteed", "perfect", "verified" or "both speakers"; time ranges in mm:ss; durations and sizes locale-formatted.

**Haptics map**: Start acknowledged — light impact; Stop acknowledged — medium impact; new limitation — single warning notification (not repeated); saved — none if partial, soft success only for "Saved" with no known gaps. All optional and mirrored visually.

At P16, use an initial group of at least five target users. Proposed usability target: at least four of five complete the core task sequence without coaching, and no unresolved misunderstanding of whether required audio was captured or whether Stop ended capture. Record task times, failure points and confidence in the result. This small study guides fixes; it is not a statistical claim of universal usability.

## 15. Initial measurable acceptance profile

These are **development acceptance targets**, not observed device performance or commercial guarantees. P02 freezes them in a versioned policy. Deterministic tests use controllable clocks. P14 measures actual behaviour; any necessary policy change must be documented and affected tests rerun.

| Area | Initial target / hard rule | Measurement |
|---|---|---|
| Startup | 15-second deadline after selection and required system permission flow finish | Missing required evidence produces an inconclusive/failed start, not success |
| Audio progress | 2-second stale threshold only for a source contract that expects continuous delivery | Monotonic time since actual progress; silence content is evaluated separately |
| Video progress | Use source cadence and frame status; no universal unchanged-frame timeout | Static, idle, blank and stopped fixtures |
| Failure display | Within 1 second of a diagnosed fault while the app can execute | Detection-to-state-update latency; background suspension reported separately |
| Stop acknowledgement | Within 1 second while executing | UI shows capture stopping/off separately from file saving |
| Accepted-input drain | 5-second deadline | Undrained accepted ranges become explicit losses/recovery work |
| Finalization | 30-second deadline after drain | Deadline expiry preserves the recovery set and releases the active lifecycle safely |
| Recovery checkpoint | Target at most 5 seconds of uncheckpointed media in normal supported operation | Measured per required source; target must be proved for the chosen writer |
| Queue bounds | Initially 32 MiB retained video; audio at most 2 seconds and 4 MiB, whichever limit arrives first | Include tasks, buffers and all intermediate queues; overflow never silent |
| Recovery retries | At most 2 automated repair attempts per item per app launch | Then quarantine/preserve; explicit retry is separate |
| A/V synchronization | Initial target absolute drift no more than 100 ms after alignment | Known time markers at start, middle and tail |
| File claims | No FULL_CHECKS_PASSED until required full coverage finishes | Validator coverage tied to the exact file |
| Known loss | Zero known required-source gaps omitted from final report | Injected ranges reconciled with anomaly ledger |
| Deletion | Zero resurrection from remaining app-owned recovery material after reconciled deletion | Terminate at every deletion transaction boundary |

The checkpoint target is not a guarantee of 5-second maximum loss under power failure. Report process-kill, reboot and other tested outcomes separately. Do not advance a checkpoint from a timer or file size.

Before M1, also freeze a storage reserve formula covering expected encoding rate, finalization workspace, journal writes and margin. Do not use one hard-coded “minutes remaining” estimate for every format.

ResourceGovernor states: NORMAL, CONSERVE, AUDIO_PRIORITY, PROTECTED_STOP. Only optional work/video quality may degrade automatically within the declared contract. Losing required media remains a reported loss.

## 16. Phase map and canonical branches

This table is the single phase-ID authority for the v2 roadmap.

| Phase | Deliverable | Canonical branch | Physical iPhone test required? |
|---|---|---|---|
| P00 | Repository foundation and build tooling | phase/p00-foundation | No |
| P01 | Platform/API research and native compilation | phase/p01-platform-contracts | No |
| P02 | Contracts, lifecycle, protection and design-system foundation | phase/p02-core-contracts | No |
| P03 | Production CaptureEngine and synthetic adapter | phase/p03-capture-engine | No |
| P04 | MediaWriter, audio policy and checkpoints | phase/p04-media-writer | No |
| P05 | HealthVerifier, anomaly ledger and validation | phase/p05-verification | No |
| P06 | RecordingStore, recovery, deletion and migrations | phase/p06-storage-recovery | No |
| P07 | Diagnostics and resource governance | phase/p07-diagnostics-resources | No |
| P08 | Premium recording UI, setup, Settings and Live Activity | phase/p08-recording-ux | No |
| P09 | Polished playback, searchable library and export | phase/p09-library-export | No |
| P10 | Privacy/security/accessibility review | phase/p10-privacy-accessibility | No |
| P11 | Commercial V1 and entitlement handling | phase/p11-commercial | No |
| P12 | Complete application integration/build audit — M1 | phase/p12-complete-build | No |
| P13 | Signing and TestFlight delivery — M2 | phase/p13-distribution | No runtime device test |
| P14 | Physical iPhone validation — M3 | phase/p14-device-validation | Yes — first physical phase |
| P15 | Device findings, fixes and retest — M4 | phase/p15-device-remediation | Yes |
| P16 | Beta acceptance and release readiness — M5 | phase/p16-release | Yes, for declared release scope |

No phase tag uses “device verified” before P14. Suggested tags: pNN-build-accepted for P00–P12, v1.0.0-build-complete at M1 and an explicitly scoped release-candidate tag after P15.

## 17. Detailed implementation phases

### P00 — Repository foundation and build tooling

**Build:** Confirm repository identity and working tree, preserve unrelated work, create a native SwiftUI app/project/test target, strict-concurrency baseline, core folders, documentation and macOS CI.

**Verify without iPhone:** Debug simulator compilation, unit-test execution, unsigned Release device-SDK compilation, configuration/secret/dependency audit. Pin and record toolchain details.

**Exit:** Foundation builds pass; no invented recording controls or device claims; exact SHA reviewed. Apple membership, signing and an iPhone install do not block this phase.

### P01 — Platform research and native compilation

**Build:** Source/availability table; actual SDK compilation of picker, stream, outputs, background declarations, stop/error callbacks and writer alternatives. Record minimum OS and all unproven runtime assumptions. Evaluate both capture candidates in section 3 (ScreenCaptureKit and ReplayKit Broadcast Upload Extension), record the supported-device list and write `docs/platform/capture-path-decision.md`.

**Verify without iPhone:** Compile native adapters against the selected SDK; test capability mapping and unavailable-path handling. Read Apple's reference implementation without assuming it proves third-party call audio.

**Exit:** Documented/compiled architecture decision and unknowns register. No early runtime GO/NO-GO gate; call feasibility remains assigned to P14.

### P02 — Contracts, lifecycle, protection and design foundation

**Build:** CaptureContract, EvidenceRecord, truth-state types, SessionController transitions, monotonic clock abstraction, deadline policy, storage transactions and file-protection/backup decisions. Define section 14 design tokens, native component contracts, navigation, screen/state inventory and evidence-to-copy mapping before implementing the screens.

**Verify without iPhone:** Transition/property tests for rapid start/stop, cancellation, timeout, generation isolation and singleton ownership. Review the design specification and representative component previews. Freeze the engineering and UX acceptance profiles.

**Exit:** Every start/stop/failure path has a deterministic result. File protection and consent are architectural requirements before media implementation. The premium UI direction, state terminology and component ownership are documented; actual hardware ergonomics remain deferred.

### P03 — Production CaptureEngine and synthetic adapter

**Build:** Real native capture adapter, lightweight callbacks, bounded ingress, source/format epochs, route/selection/error handling and a deterministic test adapter.

**Verify without iPhone:** Native device-SDK compilation; controlled sample delivery, stale callbacks, blank/idle/stopped statuses and malformed input tests through the test adapter.

**Exit:** Production capture code exists and compiles. Synthetic events cannot be selected in the shipping configuration or enter compatibility evidence. No claim that real call audio has been tested.

### P04 — MediaWriter, audio policy and checkpoints

**Build:** Select the production backend; implement encoding/mixing, timestamp mapping, writer receipts, bounded queues, checkpoint transactions, reserve-space checks and bounded stop.

**Verify without iPhone:** Known media fixtures, missing source, duplicate source content, sample-rate/channel changes, backpressure, early fragment failure, disk write errors and delayed tail. Compare native/custom alternatives in separate runs if required.

**Exit:** Fixture output passes independent media checks; chosen backend has explicit recoverability evidence semantics. Source arrival alone cannot mark output as saved.

### P05 — Health, anomaly ledger and RecordingValidator

**Build:** Five proof domains (input, timing, content, write, persistence), per-source freshness, cumulative anomalies, quick/full validation and source-to-file reconciliation.

**Verify without iPhone:** False-positive/false-negative fixtures, all-zero audio, genuine silence, missing middle/tail, healthy restart after a gap and stale status displays.

**Exit:** All mandatory negative cases yield honest states. Full file validation is bounded/resumable; participant capture remains separately qualified.

### P06 — Store, recovery, deletion and migrations

**Build:** Library states, crash-safe manifests, fragment recovery, quarantine, immutable masters, deletion transactions, schema migration and derived-file ownership.

**Verify without iPhone:** Broken-media corpus, interrupted commit/recovery/delete/migration, unknown schema, protection-access-denied simulation and low-space recovery.

**Exit:** No silent loss of the only recoverable copy; no deleted-item resurrection in tested transactions; no app-wide crash loop from a bad item.

### P07 — Diagnostics and resource governance

**Build:** Bounded technical ring buffer, reason codes, safe report export, resource states and operational measurements. Do not collect media content by default. Optionally include on-device MetricKit crash/hang diagnostics in the user-exported report; nothing is sent automatically and no third-party crash SDK is used (rule 26).

**Verify without iPhone:** Simulated pressure, queue-limit enforcement including pending tasks, export redaction, finite retry behaviour and budget transitions.

**Exit:** Every significant failure can be explained from a user-exported report. Hardware battery/thermal/background claims remain pending.

### P08 — Premium recording UI, setup and Settings

**Build:** Implement section 14's design system and Record/Recordings/Settings navigation; complete polished, real controller-connected dashboard, setup, active recording, saving/result and Settings screens. Include Important mode, anomaly details, accessible controls, appearance preferences, finished brand assets and Live Activity with stale state. Build the internal component/state preview catalogue.

**Verify without iPhone:** UI automation of normal, limited, denied, cancelled, timed-out, interrupted and stale states using explicitly simulated inputs. Review light/dark screenshots, small/large layouts, Dynamic Type, contrast, focus semantics, motion settings and optional-visual load behaviour. Execute applicable UX01–UX11 and UX16–UX18 checks.

**Exit:** Required recording/Settings screens are finished rather than placeholders. There is no fake-success button, invented waveform or hard-coded healthy badge. Every failure offers a valid next action; no pre-device compatibility claims. Independent visual/interaction review accepts the completed scope.

### P09 — Polished playback, searchable library and export

**Build:** Complete the premium library/player/export/recovery screens, local title/metadata search, sorting and outcome filters. Add playback, real saved-media waveforms where available, accessible bookmarks/gap markers, rename, deletion, partial/recovered labels, anomaly seeking, file sharing, Files export, optional Photos add-only export and audio-only derived export. Bound preview caches and preserve navigation state. Add the Settings storage view (section 14.3) with cache clearing and optional age reminders; no automatic deletion of recordings.

**Verify without iPhone:** Fixture playback and external player checks where available, damaged-file isolation, export cancellation, cleanup and ownership after entitlement changes. Check the seeded large library, unavailable previews, long titles, keyboard interactions and normal/empty/error/recovery screenshots; complete UX12–UX14 where applicable.

**Exit:** Originals remain intact, derived outputs are identifiable and core owned-file access is independent of payment state. Library/player/export design matches the same component system as the recording experience, with usable alternative controls and no preview work competing with active capture.

### P10 — Privacy, security and accessibility review

**Build:** Complete privacy/backup explanations, permission UX, optional app lock, sensitive-preview rules, protected working/master files, privacy declarations and section 14 accessibility/localization readiness. Resolve contrast, focus, large-text, reduced-motion/transparency and unclear-copy findings across every required screen.

**Verify without iPhone:** Static entitlement/manifest audit, secret scan, simulator accessibility flows, protected-file policy inspection and mocked lock/permission transitions. Record measured contrast and non-device UX gate evidence, including long localized strings and privacy-sensitive previews.

**Exit:** No misleading “never leaves the device” claim; no unnecessary permissions; real lock/biometric behaviour is explicitly queued for P14.

### P11 — Commercial V1 and entitlement handling

**Build:** Free/Pro boundaries, polished optional one-time purchase/restore screens, entitlement caching and offline behaviour. Use the platform purchase mechanism appropriate to the final product configuration. Present StoreKit's localized price, concise value and a clear dismissal; premium visual quality is included for all users.

**Verify without iPhone:** StoreKit test configuration/simulation, interrupted purchase, restore, unknown/offline entitlement, refund/revocation handling and no effect on active recording. Complete UX15 and review purchase-screen accessibility/copy without forced or misleading flows.

**Exit:** Safety and existing recordings remain accessible. Device purchase tests and real distribution checks are assigned to P14/P16.

### P12 — Complete application build and independent audit

**Build:** Integrate every scoped V1 feature, including the full professional/premium UX/UI scope. Resolve implementation TODOs and placeholder screens on required paths; finalize diagnostics, test fixtures, runtime scripts, design documentation, screenshot evidence and release configuration.

**Verify without iPhone:** Full applicable unit/integration/property/UI gates, UX01–UX18 non-device acceptance, Debug simulator build, unsigned Release device build, final configuration audit and independent code/design review of the exact SHA. Verify real production state is connected to the final screens rather than relying only on previews.

**Exit — M1:** APPLICATION_BUILD_COMPLETE. All P00–P12 requirements, premium screen designs and required non-device UX checks are implemented and accepted. Required production paths contain no test doubles. No required UX implementation is deferred as “polish later”. DEVICE_EVIDENCE_PENDING is prominently recorded; actual device usability/performance checks remain in P14.

This milestone is the user's requested point **before any physical iPhone testing begins**. Signing credentials may still be pending; an unsigned app cannot yet be installed through TestFlight.

### P13 — Signing and TestFlight delivery

**Build:** Complete Apple Developer/App Store Connect setup, bundle identity, profiles, protected credentials, signed archive and upload of the completed app. Confirm the app name is available and does not conflict with existing marks, set the version/build scheme (semantic marketing version; monotonically increasing build number derived from CI run or commit count), export-compliance answer, age rating and TestFlight test notes.

**Verify:** Archive identity, entitlements, export/upload processing and TestFlight availability. Use a distribution-supported Xcode/SDK; a successful research build does not establish distribution acceptance.

**Exit — M2:** Exact completed build available for device installation. If credentials, membership or processing are blocked, record DISTRIBUTION_BLOCKED without revoking M1 or claiming device success.

### P14 — Physical iPhone validation

**Run:** First physical installation, launch/permissions, real capture, supported-candidate calls, routes, background/lock, durations, stop/tail, storage, recovery, privacy and purchase tests. Complete section 14's physical UX follow-ups: one-handed controls, real-display readability, assistive technologies, native sheets, haptics and UI/capture performance together.

**Record:** Exact build and scenario, observed media, call quality, anomalies, saved output and limitations. Keep unsupported, failed and inconclusive results separate.

**Exit — M3:** Device-validation report and release-scope decision. This milestone may honestly report failed/unsupported call configurations; it does not itself declare release readiness.

### P15 — Fix device findings and retest

**Build:** Reproduce observed defects, make focused fixes, rerun relevant automated gates and independently review the candidate.

**Verify on iPhone:** Retest affected scenarios and any connected risks such as routing, stop, file protection, recovery, UI responsiveness or accessibility. Use the exact candidate intended for release; update affected screenshot and UX evidence after design changes.

**Exit — M4:** No unresolved release-blocking defects in declared support scope. Unavailable platform behaviour is handled by truthful scope/UX, not a fabricated fix.

### P16 — Beta acceptance and release

**Complete:** Target-user beta and the section 14 task-comprehension study, scoped device matrix, privacy/purchase/App Review package (including review notes explaining the recording indicator, consent notice and how to exercise capture), public privacy-policy and support URLs, support documentation and release artifact retention. Use actual completed screens for store screenshots and onboarding/support guidance.

**Verify:** Release checklist, affected-device retests after candidate changes, onboarding comprehension and retained-recording ownership.

**Exit — M5:** RELEASE_READY for the documented supported scenarios. Submit the validated App Store Connect build and record review outcome separately; approval is not assumed.

## 18. Non-device verification and fault matrix

Build-stage fixtures validate logic and media processing. They must be labelled synthetic and must never create a DEVICE_OBSERVED compatibility record.

| Test ID | Scenario / injected fault | Required result | Build owner |
|---|---|---|---|
| T01 | Double Record / double Stop | One session/writer; idempotent stop | P02 |
| T02 | Picker cancel / denied permission | Clean cancellation/denial; no success claim | P02 |
| T03 | Required source never arrives | Startup deadline; explicit missing/inconclusive result | P02/P05 |
| T04 | Old-generation callback | No mutation of active/new session | P03 |
| T05 | Selection changes | Old proof expires; new contract epoch | P03/P05 |
| T06 | 200 ms, 3 s and 10 s required audio loss | Detected coverage gaps retained in final report | P05 |
| T07 | Audio resumes after known loss | Current health can recover; completeness remains partial | P05 |
| T08 | Capture succeeds but writer rejects input | Source-to-file mismatch visible | P04/P05 |
| T09 | Valid buffers containing all zeros during expected speech | No claim that conversation speech was captured | P05 |
| T10 | Genuine silence | No failure based on amplitude alone | P05 |
| T11 | Static display / idle status | No false frozen-video verdict | P03/P05 |
| T12 | Blank, suspended or stopped display | Distinct reason; no invented usable-video proof | P03/P05 |
| T13 | Only local speech, only remote speech, music/noise | No automatic two-participant attribution | P05 |
| T14 | Source duplication / clipping / mixed levels | Defined mix and reported limitations | P04 |
| T15 | Invalid, duplicated, backward or discontinuous PTS | Reject/classify safely; preserve timeline gaps | P04 |
| T16 | Route/format epoch changes | Converter/track handling and fresh verification | P03/P04 |
| T17 | Writer stall and queue saturation | Hard memory bounds; drop/stop policy; no silent audio loss | P04/P07 |
| T18 | Pending tasks accumulate before writer queue | Ingress/task limits remain enforced | P03/P07 |
| T19 | First words / final words near boundaries | Captured/accepted boundaries and losses reported | P04/P05 |
| T20 | Stop while accepted work remains | Bounded drain; tail retained or explicitly partial | P04 |
| T21 | Finalization never completes | Timeout, recoverable state and responsive UI | P02/P04/P06 |
| T22 | Simulated media reset / interruption | Invalidated evidence and correct restart requirement | P02/P03 |
| T23 | File header, middle or tail corruption | Coverage-aware failure; preserve original | P05/P06 |
| T24 | Crash before first checkpoint / between transaction steps | Recover what exists; no false safe-save status | P04/P06 |
| T25 | Missing initialization segment / manifest disagreement | Preserve/quarantine; no guessed complete result | P06 |
| T26 | Disk full during capture/close/remux | Reserve/stop policy; preserve only recoverable copy | P04/P06 |
| T27 | Protected file inaccessible | Wait/report locked; do not call it corrupt | P06/P10 |
| T28 | Repeated bad recovery item | Bounded retries and quarantine; app remains usable | P06 |
| T29 | Delete interrupted by termination | Idempotent completion; no resurrection | P06 |
| T30 | Upgrade / interrupted migration / future schema | Non-destructive preservation | P06 |
| T31 | Wall-clock jump | Media timeline/watchdog correctness unchanged | P02/P04 |
| T32 | Stale Live Activity / disabled notification pathway | Unknown/stale presentation; no liveness guarantee | P08 |
| T33 | Purchase denied, offline or entitlement changed | No disruption of capture/owned-file access | P11 |
| T34 | Export fails/cancels or new recording requested during export | Original preserved; serialized work decision | P09 |
| T35 | Diagnostic report export | No default media, transcript, contact or screen-text leakage | P07/P10 |
| T36 | Optional work competes for resources | Capture policy takes priority; no unbounded backlog | P07 |

For T06, detection must use actual expected coverage and instrumented losses, not merely a timer threshold. Small gaps can be recorded after arrival even if they do not trigger an immediate user interruption.

Use invariant/property tests for state/event permutations and independent fixtures with known expected outputs. A validator must not receive its expected answer from the implementation it is verifying.

Do not require every expensive suite on every edit. Run relevant tests during development and the complete required gate at phase acceptance/M1.

### 18.1 Test tooling (v2.2)

- Swift Testing for new unit/property tests; XCTest/XCUITest for UI automation and performance where Swift Testing does not cover it.
- Deterministic clocks: inject a monotonic-clock protocol and a media-time source; no `sleep`-based tests.
- Media fixtures are generated by scripts in `scripts/fixtures/` (tones, silence, all-zero buffers, timed gaps, corrupted headers/tails) with a documented expected-result file per fixture that is written independently of the implementation.
- Snapshot/screenshot comparison uses Xcode's own UI test attachments, or a single reviewed open-source snapshot library recorded under rule 26.
- Accessibility audits use `XCUIApplication.performAccessibilityAudit()` where available, plus manual Accessibility Inspector review.
- StoreKit tests use a local `.storekit` configuration and `SKTestSession`.

The premium UX/UI matrix is UX01–UX18 in section 14.11. Its simulator, layout, state and interaction checks complement T01–T36; neither screenshot approval nor a polished interface replaces recording-integrity tests. Hardware-specific checks remain deferred to P14.

## 19. Physical iPhone testing — after M1 and TestFlight delivery

### 19.1 Device evidence record

For every run record:

- Test ID, date, app version/build, source commit and relevant configuration.
- iPhone model, exact iOS build and capture recipe/contract.
- Tested call app/version when obtainable; record unknown explicitly.
- Input and output route, relevant accessory details and user-selected settings.
- Permission/scope choices, foreground/background/lock sequence.
- First/last captured and saved boundaries, missing ranges and validation result.
- Original call quality and any impact caused by CallCapture.
- Test duration, observed outcome, repeat count and unresolved limitations.

Some third-party app/version details may need manual entry. Do not assume unrestricted inspection of other installed applications.

### 19.2 Execution order

1. Install the completed TestFlight app; launch, terminate, relaunch and check first-use permissions.
2. Test own-app/full-display capture, known non-call audio and microphone separately.
3. Test consented WhatsApp audio/video calls with speaker and AirPods.
4. Test consented FaceTime audio/video calls with speaker and AirPods.
5. Test route changes, accessory disconnect, mute/volume changes, orientation, background and lock.
6. Test Stop, system Stop, restart, first/final words and independent playback/export.
7. Run long-duration/resource/recovery/privacy/purchase tests for supported candidate configurations.
8. Record failed, unsupported and inconclusive configurations as first-class results.

A failed route does not require falsely passing it to release another proven route. It requires truthful exclusion or a clearly described limited mode.

### 19.3 Controlled call script

With willing test participants, use separate local and remote phrases at start, middle and immediately before Stop:

~~~text
Local only: Alpha One / Alpha Two / Alpha Three.
Remote only: Bravo One / Bravo Two / Bravo Three.
Both: alternating numbered phrases, then a short overlap.
Silence: both remain quiet for a known interval.
Background control: a distinct non-speech sound.
~~~

The tester checks actual saved media against the script. This validates the controlled run; it does not turn automatic speech detection into proof of both participants in all later calls.

### 19.4 Minimum release-scope matrix

| Dimension | Required coverage |
|---|---|
| Call type | Each publicly advertised application and audio/video scenario |
| Route | Each advertised speaker/headphone route, plus transitions relevant to the claim |
| Lifecycle | Foreground, other app foreground, background, lock/unlock and stop/relaunch |
| Duration | 5/30/60/120-minute sessions across every advertised long-duration configuration |
| Resources | Low storage during start/capture/finish, Low Power Mode, observed memory/thermal pressure |
| Failures | Process termination during capture/Stop/finalization and app-update recovery |
| Privacy | File access while locked, new segments while locked, app lock and export/backup explanations |
| UX | Status comprehension, denied permissions, unknown audio, unavailable alerts, one-handed Start/Stop, supported layouts, light/dark readability and all section 14 physical follow-ups |
| Accessibility | VoiceOver, Voice Control, Switch Control, large text, contrast/motion/transparency settings and every shipped language in declared scope |
| UI/resource interaction | Visible meters, library navigation, screen changes and optional haptics during capture; measured responsiveness and resource impact |
| Ownership | Playback/export/delete with offline or changed purchase state |

Where a duration/route combination is untested, report that scope explicitly instead of extrapolating. Start with the user's iPhone; broader device support requires appropriate additional device evidence. Include at least an older and a newer supported device before making a broad hardware claim.

Deliberate fault-injection controls belong in an internal test configuration. Document differences from the shipping build. Validate the ordinary supported flows again on the exact release candidate; do not call a differently configured diagnostic binary the release binary.

Device health heuristics may be tuned only through a versioned change record. Do not lower a requirement silently to make a failed run pass.

## 20. CI, signing and evidence retention

Windows remains a supported development workstation. Use a macOS/Xcode build environment for Apple compilation.

Because this repository is public, standard GitHub-hosted macOS runners are available without per-minute charges under GitHub's current public-repository terms (recheck before relying on it). This is the default way to compile, test and capture simulator screenshots from a Windows workstation. Trigger expensive jobs on pull requests and manual dispatch, use concurrency groups to cancel superseded runs, and keep signing jobs manual-only with protected environments. A Mac (local or rented) is still needed for interactive Xcode work such as Instruments and design review if CI artifacts are insufficient.

Before M1:

- Debug simulator build and relevant test execution.
- Unsigned Release device-SDK compile.
- Native symbol availability checks.
- Privacy/entitlement/background-mode audits.
- Dependency and secret checks.
- Deterministic media/fault tests and simulator UI automation.

Keep a recorded, known toolchain for core tests and a separate newer-SDK research lane where needed. Once production capture depends on the newer SDK, its successful native compile is a required M1 gate; an older lane cannot stand in for it.

Use budget controls: cancel superseded CI runs, avoid duplicate expensive jobs, bound artifact retention and keep signed uploads manually triggered. If macOS runner access/minutes are unavailable, record BUILD_VERIFICATION_BLOCKED; do not substitute unexecuted commands for a passing build.

P13 prerequisites: Apple Developer membership, App Store Connect app record, bundle ID, signing strategy, appropriate credentials and a distribution-supported SDK. Prepare instructions earlier, but do not make device installation an early dependency.

Store credentials only in appropriate secret storage. Never commit private keys/certificates or print them in logs. Use limited CI permissions and an isolated signing environment.

Retain commit SHA, Xcode/SDK versions, archive metadata, App Store Connect build identity, configuration, test reports and dSYMs as appropriate. Apple may process uploaded binaries; identify the tested distributable by its actual platform build identity rather than promising byte-for-byte equality with every installed variant.

Do not rebuild and silently substitute a different release candidate. Changes after physical validation require impact analysis and relevant retesting.

### 20.1 Dependency and repository hygiene (v2.2)

- Prefer Apple frameworks; each third-party package needs a recorded licence, version pin, purpose, privacy impact and update owner in `docs/dependencies.md`.
- `.gitignore` excludes DerivedData, `*.xcuserstate`, build products, `*.p12`, `*.mobileprovision`, `.env` and local recordings/fixtures larger than the agreed size.
- Secret scanning runs in CI; GitHub secret scanning/push protection is enabled for the public repository.
- Generated media fixtures are produced by scripts rather than committed when they are large.

## 21. Commercial scope and user value

### Free foundation

- Basic supported recording modes.
- Honest health, missing-audio warnings and setup checks.
- Playback, rename, delete and standard export.
- Recovery of available user-owned media.
- Basic anomaly information needed to understand an incomplete recording.
- The full premium visual baseline, light/dark appearance, accessibility, basic library search and outcome filters.
- Storage view, Restore Purchases, privacy/consent information and diagnostics report export (section 14.3).

### One-time Pro candidates

- Detailed diagnostic/history views.
- Advanced organization and bookmark tools.
- Convenience export presets.
- App-lock convenience, with baseline file protection retained for all users.
- Optional stricter workflow presets; their underlying safety rules remain universal.

Do not charge a person to discover that their selected route is unsupported. Do not let purchase checks interrupt an active recording. An unknown purchase state does not erase recordings or block essential owned-file access.

Apple already provides recording for supported Phone/FaceTime audio scenarios. Validate CallCapture's specific advantage with target users: observable health, clear gaps, recovery, organization and export. [S11]

During the post-build beta, run section 14.11's target-user task study: start, identify an audio limitation, stop, find an affected interval and export. Record task success and confusion, then fix misunderstood labels and flows before release. Evaluate premium design through usability and consistency as well as appearance.

## 22. Optional post-release technology

These are planned extensions after core device validation, not prerequisites for APPLICATION_BUILD_COMPLETE.

| Extension | Technology direction | Required constraint |
|---|---|---|
| Timestamped transcription | SpeechAnalyzer / SpeechTranscriber | Device/language availability and model assets checked |
| Summaries and action items | Available Foundation Models capabilities | Explicit opt-in; source timestamps; availability fallback |
| Transcript search | Local indexing after recording | No capture-path contention; user deletion removes owned index data |
| Enhanced audio | Derived-file processing | Preserve original; enhancement cannot recreate missing speech |
| Encrypted backup/sync | Separately designed service | Clear consent, key recovery, deletion and conflict policy |

Apple's SpeechAnalyzer supports on-device processing, but language/model assets may need download. Evaluate Urdu, English and mixed speech with representative recordings rather than assuming equal accuracy. [S12]

On-device Foundation Models availability depends on supported device/configuration. Handle unavailability without affecting recording. Treat transcript content as data, not as instructions that can initiate tool actions or uploads. AI output is never capture-health evidence. [S13]

## 23. Risks, scope decisions and failure severity

| Risk | Treatment during build | Decision after physical testing |
|---|---|---|
| Remote call audio not supplied | Implement unknown/unavailable states and negative fixtures | Exclude unsupported scenario or explicitly revise product scope |
| Background/lock capture differs from assumptions | Compile official configuration; simulate events | Scope support to measured behaviour; fix genuine defects |
| Writer has insufficient checkpoint visibility | Select backend and accurately limit persistence claims | Validate recoverability under declared failure models |
| Some iOS symbols differ from macOS/docs | Compile a per-symbol availability table | Revise adapter/profile based on device evidence |
| Alert cannot be delivered promptly | Stale/unknown presentation, no guaranteed alert promise | Describe observed alert limitations |
| Signing/SDK/CI capacity unavailable | Preserve implementation; classify exact verification block | Resolve delivery before runtime acceptance |
| “Both speakers” cannot be automatically proved | Do not expose that automatic claim | Keep participant completeness unconfirmed |
| Device backup differs from app cloud setting | Clear separate policy | Verify accessible behaviour without impossible guarantees |
| Visual effects compete with capture or obscure evidence | Bound meter/cached-preview work; retain plain readable state and Stop; verify synthetic load | Profile on-device and remove/degrade optional effects before compromising capture |
| Polished UI gives false confidence or hides a failure | Evidence-to-copy mapping, persistent gap notice and independent state review | Use real-scenario and target-user comprehension findings to correct claims and presentation |
| ScreenCaptureKit on iOS proves unsuitable (availability, picker or background limits) | Compile and evaluate ReplayKit broadcast candidate B in P01; keep the capture adapter small | Switch adapter only with a recorded decision and rerun affected gates |
| Broadcast extension memory limit (candidate B) | Bounded buffers; write segments from the extension; measure in synthetic load | Measure on device; reduce video quality before risking required audio |
| Recording used unlawfully or covertly | Consent/legal notice (13.2), visible indication, no hidden mode | Review App Review feedback and support reports |
| No Mac available for interactive work | Use free public-repo macOS CI for builds/tests/screenshots | Arrange Mac access before P13 signing if CI signing is not chosen |

A developer's reported iOS 27 silent VoIP buffers are a useful negative-test motivation, not proof that every calling app fails. [S14]

A previously reported screen-capture background-mode upload rejection was marked resolved by Apple DTS. Do not copy it into the current blocker list without reproducing a current failure. [S15]

Use severity labels distinct from phase IDs:

- **SEV-0:** false assurance about missing required media, serious privacy breach, or capture continuing contrary to an authoritative stop.
- **SEV-1:** recording loss, unrecoverable corruption, call disruption, deleted-item resurrection or persistent crash loop.
- **SEV-2:** functional degradation that is safely reported but affects the declared supported scope.
- **SEV-3:** low-impact presentation or convenience defects.

An honestly reported, declared unsupported route is a capability outcome, not automatically a software incident. SEV-0/SEV-1 findings block release. Other findings require recorded disposition.

## 24. Phase workflow and reviewer handoff

For P00–P12:

1. Freeze phase scope, requirement IDs and acceptance tests.
2. Claude implements focused changes.
3. Run relevant checks, then the required phase gate.
4. Cursor independently reviews the exact commit and tests the risky assumptions.
5. Claude fixes confirmed findings; rerun affected checks and review the final SHA. For P08–P12, include the relevant UX gate, appearance/state evidence and interaction review.
6. Record phase acceptance under the user's existing authorization/phase-control workflow.
7. Proceed with the recorded next phase. No physical iPhone request is introduced.

For P13–P16 add distribution/device evidence only as specified by their gates.

Prefer a report-only independent review followed by author fixes. If the reviewer changes code, the change is recorded and receives an independent review before being treated as accepted.

Missing reviewer access is REVIEW_PENDING, not PASS. Missing physical evidence in P00–P12 is the planned deferral, not a failed phase.

An open Critical/High implementation finding blocks acceptance of its build phase. Planned uncertainty about physical call behaviour is recorded separately and is not reclassified as an early device-testing prerequisite.

Every handoff includes:

~~~text
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
~~~

Do not edit success criteria retrospectively without a documented change reason and revalidation. No force pushes, unrelated edits or imported historical PASS claims.

### 24.1 Execution records (v2.2)

Keep these short, current files so work can resume after any interruption:

| File | Contents |
|---|---|
| `docs/execution/PROGRESS.md` | Phase status table (implementation / build-test / independent review / device — four separate columns), exact commit, tests actually run |
| `docs/execution/BLOCKERS.md` | Open blockers, what each blocks, what is needed and from whom |
| `docs/execution/RESUME_STATE.md` | Current phase, branch, last commit, next concrete action |
| `docs/reviews/CURSOR_REVIEW_INDEX.md` | Each review handoff, reviewed SHA, findings and disposition; `INDEPENDENT_REVIEW_PENDING` where none occurred |

Self-review by the implementer is recorded as self-review and never as independent acceptance.

## 25. Release checklist

- [ ] M1 application build and independent review complete.
- [ ] Premium UX/UI is implemented across all required screens; UX01–UX18 non-device results and physical follow-ups are recorded.
- [ ] Design tokens, light/dark appearance, critical state copy, app icon and actual-build screenshots are consistent.
- [ ] Exact TestFlight candidate identified and installed in the physical phase.
- [ ] Every advertised capture scenario has current device evidence.
- [ ] Unsupported/unknown scenarios have accurate UI and marketing scope.
- [ ] Current health and cumulative completeness remain separate.
- [ ] Missing media is reconciled from input through saved output.
- [ ] Start/stop deadlines, tail handling and safe interruption behaviours pass.
- [ ] Original call quality is not unacceptably disrupted in supported scenarios.
- [ ] Duration/resource/route/lifecycle matrix passes for the declared scope.
- [ ] Recovery, deletion and migration tests pass.
- [ ] Privacy/protection/backup/export policies match observed behaviour.
- [ ] Permission/consent and visible indication requirements pass.
- [ ] Purchase flows, restore and offline ownership behaviour pass.
- [ ] Accessibility and target-user beta findings have dispositions.
- [ ] No unresolved UX defect obscures Stop, misstates capture completeness or blocks essential access; required accessibility/contrast/layout checks pass.
- [ ] Optional visuals, previews and haptics meet measured device resource limits without compromising capture.
- [ ] Required full validation coverage passes without hiding capture limitations.
- [ ] No open SEV-0/SEV-1 issue; other findings have recorded disposition.
- [ ] Validated build selected for submission; sources and claims rechecked.
- [ ] App Review package, support guidance and evidence retention are ready.
- [ ] Privacy-policy and support URLs are live; age rating, export compliance and app-name check are complete.
- [ ] Recording-law/consent notice is present and App Store copy does not encourage covert recording.
- [ ] Every usage-description string and capability in section 13.1 is present, accurate and actually used.
- [ ] Dependency register is current; no third-party analytics/tracking SDKs.

## 26. Improvement traceability

| Review improvement | Implemented in this plan |
|---|---|
| Physical testing after complete application build | Sections 1, 16–19; P12–P15 |
| Scope call-audio feasibility honestly | Sections 2–3, 6–7, 19, 23 |
| Replace ambiguous Verified promises | Sections 6–7, 12, 14 |
| Separate current health from cumulative gaps | Sections 6–7; T06–T07 |
| Match capture, writer and saved media evidence | Sections 6, 10, 12; T08 |
| Give user information while another app is foreground | Section 14; T32; P14 |
| Define recoverable checkpoints and failure models | Sections 10–11, 15; T24–T26 |
| Separate basic and full validation coverage | Section 12; T23 |
| Prevent setup test from promising future call audio | Section 14; P08 |
| Make Important mode requirements observable | Sections 6, 14; T03 |
| Move lifecycle/privacy foundations earlier | P02 before capture/writer |
| Preserve original call quality | Section 9; P14 |
| Handle cancellation, interruption and media reset | Section 8; T02/T22 |
| Distinguish silence/static/blank from actual failures | Section 9; T09–T12 |
| Measure first/last captured words and bounded stop | Sections 8, 15; T19–T21 |
| Define mixing and route-format changes | Section 9; T13–T16 |
| Use monotonic watchdogs alongside media time | Sections 4, 6, 15; T31 |
| Bound ingress, queued tasks and memory | Sections 9, 15; T17–T18 |
| Clarify single-writer scope | Sections 4–5, 10; T34 |
| Account for file protection during locked recording | Sections 11, 13, 19; T27 |
| Separate app cloud settings from system backup | Section 13 |
| Prevent deletion resurrection | Section 11; T29 |
| Preserve data through schema migrations | Section 11; T30 |
| Use independent media fixtures and expected results | Section 18 |
| Improve compatibility granularity and honest scope | Sections 3, 7, 19 |
| Keep safety and owned recordings outside paywalls | Sections 4, 14, 21; T33 |
| Evaluate native writer and newer on-device AI | Sections 10, 22 |
| Keep phases/branches and severity names consistent | Sections 16, 23 |
| Control CI cost and exact-build evidence | Section 20 |
| Establish customer benefit beyond native recording | Section 21 |
| Make professional/premium UX/UI mandatory in V1 | Section 14; P02/P08–P12; M1 |
| Define a consistent native visual system and light/dark appearance | Sections 14.1–14.3; UX01/UX04/UX09 |
| Polish onboarding, active recording, results, library and player | Sections 14.3–14.7; P08–P09; UX10–UX13 |
| Prevent polished visuals from implying unsupported recording success | Sections 14.5/14.7/14.9; UX06/UX17 |
| Protect capture performance from optional UI work | Section 14.7; UX16; T36; P14 |
| Make accessibility, localization readiness and usability measurable | Sections 14.8/14.11; UX02–UX05/UX08/UX14/UX18; P10/P14/P16 |
| Keep premium presentation separate from the Pro paywall | Sections 14.1/21; UX15; P11 |
| v2.2: Evaluate ReplayKit broadcast path alongside ScreenCaptureKit | Sections 3, 5.1, 23; P01 |
| v2.2: Target, permission, consent-law and dependency inventories | Sections 5.1, 13.1, 13.2, 20.1; rule 26 |
| v2.2: Concrete UX token proposal, wireframes, journeys and mockup | Section 14.12; `docs/ux/mockups/` |
| v2.2: Test tooling, free public-repo macOS CI, execution records | Sections 18.1, 20, 24.1 |
| v2.2: App Store submission completeness | P13, P16, section 25 |

## 27. Source register

Platform references were consulted in the two review rounds and the premium UX/UI revision on 1 October 2026. Recheck availability and distribution requirements when implementing. Engineering, visual and usability acceptance targets in this roadmap are proposed product requirements, not Apple guarantees.

- **S1 — Apple iOS ScreenCaptureKit sample:** [Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios).
- **S2 — GitHub toolchain availability:** [Xcode 27 runner image now runs on macOS 27](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/).
- **S3 — Apple media-service reset handling:** [mediaServicesWereResetNotification](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification).
- **S4 — Apple static-frame semantics:** [SCFrameStatus.idle](https://developer.apple.com/documentation/screencapturekit/scframestatus/idle).
- **S5 — Apple audio-route changes:** [Responding to Route Changes — archived programming guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html). Consult the current AVAudioSession reference and selected SDK alongside this conceptual guidance.
- **S6 — Apple fragmented writing:** [Author fragmented MPEG-4 content with AVAssetWriter](https://developer.apple.com/videos/play/wwdc2020/10011/).
- **S7 — Apple first-fragment behaviour:** [initialMovieFragmentInterval](https://developer.apple.com/documentation/avfoundation/avassetwriter/initialmoviefragmentinterval).
- **S8 — Apple recording consent/background rules:** [App Review Guidelines, including 2.5.4 and 2.5.14](https://developer.apple.com/app-store/review/guidelines/).
- **S9 — Apple backup semantics:** [Optimizing Your App's Data for iCloud Backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup).
- **S10 — Apple Live Activity freshness:** [staleDate](https://developer.apple.com/documentation/activitykit/activitycontent/staledate).
- **S11 — Apple native call recording:** [How to record a call on iPhone and iPad](https://support.apple.com/en-us/121583).
- **S12 — Apple on-device speech:** [Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/).
- **S13 — Apple on-device model availability:** [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).
- **S14 — First-person developer report, not universal platform policy:** [SCStreamOutputType.audio delivers all-zero PCM for VoIP background audio](https://developer.apple.com/forums/thread/848245).
- **S15 — Apple DTS response and reporter follow-up:** [ScreenCaptureKit screen-capture background-mode upload thread](https://developer.apple.com/forums/thread/840821).
- **S16 — Apple touch-target and layout guidance:** [UI Design Dos and Don'ts](https://developer.apple.com/design/tips/).
- **S17 — Apple material hierarchy and Liquid Glass guidance:** [Materials — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/materials).
- **S18 — Apple accessibility evaluation guidance:** [Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app).
- **S19 — Apple ReplayKit broadcast extension (added v2.2, recheck at P01):** [RPBroadcastSampleHandler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler) and [RPSystemBroadcastPickerView](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview).

## 28. Immediate implementation starting point

1. Read this v2 roadmap and the repository instructions.
2. Confirm repository identity, actual branch/commit and existing implementation.
3. Map existing work to P00–P12; retain useful implementation and revalidate its evidence.
4. Start at the first incomplete build phase.
5. Maintain a separate DEVICE_EVIDENCE_PENDING register throughout development.
6. Complete the production application, premium UX/UI and the M1 engineering/design review gate; finish section 14's non-device acceptance requirements.
7. Deliver the completed build through P13.
8. Begin physical iPhone testing in P14, then complete fixes, retesting and release gates.

**The development sequence is: complete app build → signed delivery → physical iPhone validation → fixes and retest → release.**
