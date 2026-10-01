# P01 — Capture path decision and symbol table

**Date:** 1 October 2026
**Evidence level:** DOCUMENTED + SDK_COMPILED (once CI compiles the iOS target). No runtime device evidence — call feasibility is assigned to P14.

## Toolchains checked (GitHub-hosted runners, 1 Oct 2026)

| Runner label | macOS | Default Xcode | iOS SDK | Simulator runtimes | ScreenCaptureKit in iOS SDK |
|---|---|---|---|---|---|
| `macos-15` | 15.7.9 | 16.4 | 18.5 | 18.5, 18.6, 26.0–26.2 | No |
| `macos-26` | 26.6.2 | 26.6 | 26.5 | 26.2, 26.4, 26.5 | No |
| `xcode-27` (public preview, standard size) | 27.0 | 27.0 (27A266a) | 27.0 | iOS 27.0 | **Yes** |

Source: `.github/workflows/toolchain-probe.yml` runs; the iOS 27 headers and Swift interfaces were captured as a CI artifact (7-day retention).

**Selected build toolchain:** `xcode-27` runner, Xcode 27.0, iOS 27.0 SDK, Swift 6.4. This is a GitHub *preview* image; if it changes or is withdrawn, record `BUILD_VERIFICATION_BLOCKED` instead of substituting an older SDK (roadmap section 20).

## Candidate comparison

| Requirement | A — ScreenCaptureKit (iOS 27) | B — ReplayKit Broadcast Upload Extension |
|---|---|---|
| Public API in current SDK | `SCContentSharingPicker`, `SCStream`, `SCStreamOutputType.screen/.audio/.microphone`, `SCRecordingOutput` (ios 27.0) | `RPBroadcastSampleHandler`, `RPSystemBroadcastPickerView` (iOS 12+) |
| System picker, explicit start | Yes (`present()`), with a microphone toggle in the picker | Yes (broadcast picker button) |
| Runs in | App process (background mode `screen-capture`) | Separate extension process |
| Memory budget | App budget | Extension limit (historically ≈50 MB — must be measured) |
| Frame status (idle/blank/suspended/stopped) | Yes (`SCStreamFrameInfo.status`) | No equivalent |
| Stop/error reasons | `SCStreamErrorCode` incl. userStopped, systemStoppedStream, insufficientStorage, missingBackgroundMode | `finishBroadcastWithError` / limited |
| Writer checkpoint visibility | Custom AVAssetWriter segment output (chosen) | Same writer would run inside the extension |
| Hand-off to library | Direct | App Group container required |
| Remote call audio supplied? | **UNTESTED** (P14) | **UNTESTED** (P14) |

## Decision

**V1 production path: A (ScreenCaptureKit on iOS 27).** Minimum iOS: **27.0**.

Reasons: richer observable evidence (frame status, specific stop reasons), in-app process without the extension memory limit, a system picker that includes a microphone control, and direct storage access. B stays a documented fallback; its public symbols are referenced in `ScreenCaptureKitEngine.swift` (`ReplayKitCandidateReference`) so they remain SDK_COMPILED. Only one capture backend and one writer backend ship per session (rules 1–2).

## Writer backend decision (P04)

`SCRecordingOutput` writes a finished file but exposes only `recordedDuration`/`recordedFileSize` and start/finish/fail callbacks — no checkpoint receipts. Per section 10.1 it is not treated as proving durability. **Production writer: `SegmentedTrackWriter`** — one `AVAssetWriter` per source × format epoch in delegate segment mode (`outputFileTypeProfile = .mpeg4AppleHLS`, 2 s preferred segments). Each initialization and media segment is committed by `SegmentCommitter` (staging → rename → checksum → atomic manifest) *before* a checkpoint is reported. Separate tracks preserve source provenance; the master (`master.mov`) is assembled by passthrough after capture.

Declared failure model: app-process termination after a committed checkpoint leaves a recoverable prefix (init + committed segments). System reboot and sudden power loss are not claimed until P14 measures them.

## Symbol / requirement table (iOS 27.0 SDK)

| Framework | Symbol | Availability | Requirement / note | Fallback |
|---|---|---|---|---|
| ScreenCaptureKit | `SCContentSharingPicker.shared`, `present()`, `isAvailable` | iOS 27.0 | Genuine system picker only | Start disabled with reason |
| ScreenCaptureKit | `SCContentSharingPickerConfiguration.showsMicrophoneControl` | iOS 27.0 | Mic choice reflected in `SCContentFilter.isMicrophoneEnabled` | Mic becomes optional in a new contract segment |
| ScreenCaptureKit | `SCStream`, `addStreamOutput(_:type:sampleHandlerQueue:)`, `startCapture`, `stopCapture` | iOS 27.0 | `UIBackgroundModes: screen-capture` (else `SCStreamErrorMissingBackgroundMode`) | — |
| ScreenCaptureKit | `SCStreamOutputType.audio` / `.microphone` | iOS 27.0 | `capturesAudio`; mic needs `audio` background mode + `AVAudioSession(.playAndRecord)` for background delivery (Apple sample) | Source shown as unconfirmed/unavailable |
| ScreenCaptureKit | `SCStreamConfiguration.minimumFrameInterval`, `pixelFormat` | **unavailable on iOS** | Frame-rate control not available | Writer scales/encodes what is delivered |
| ScreenCaptureKit | `SCRecordingOutput` | iOS 27.0 | Development comparison only | — |
| AVFoundation | `AVAssetWriter` delegate segment output | iOS 14+ | Production writer | — |
| AVFAudio | `mediaServicesWereResetNotification`, `routeChangeNotification` | iOS 6+ | T22 / T16 handling | — |
| ActivityKit | `Activity.request`, `ActivityContent(staleDate:)` | iOS 16.2+ | Projection only, stale presentation | In-app strip |
| StoreKit 2 | `Product`, `Transaction.currentEntitlements`, `AppStore.sync` | iOS 15+ | Pro isolated from capture | Cached state; core never gated |
| ReplayKit | `RPBroadcastSampleHandler`, `RPSystemBroadcastPickerView` | iOS 12+ | Candidate B reference only | — |

## Unproven runtime assumptions (DEVICE_EVIDENCE_PENDING → P14)

1. Whether `.audio` delivers another app's VoIP/FaceTime call audio (a developer report describes all-zero VoIP buffers in background — S14).
2. Whether activating `AVAudioSession(.playAndRecord, .mixWithOthers)` disturbs an ongoing call's audio route or quality.
3. Background/lock behaviour with `screen-capture` + `audio` modes over long sessions; behaviour when Live Activities are disabled.
4. New-segment creation while locked with `completeUntilFirstUserAuthentication` protection.
5. AirPods/Bluetooth HFP route changes and resulting format epochs.
6. App Review acceptance of the background modes for this use.

## Supported devices

Every iPhone that can install iOS 27.0. The exact model list will be taken from Apple's iOS 27 compatibility page at P13. Broad hardware claims need the older/newer device evidence in roadmap section 19.4.
