# Physical iPhone test log (P14)

Every run is recorded against the exact build. Results are DEVICE_TESTED only for what was
observed; nothing here extrapolates to other call apps, routes or durations (roadmap section 19).

## DT-01 — first install and short screen recording (23 Oct 2026)

| Field | Value |
|---|---|
| Build | 1.0.0 (16), commit `4281f7f`, TestFlight (internal group "Owner") |
| Device / iOS | Owner's iPhone, iOS 27 (exact model/build not recorded) |
| Scenario | Start → system picker → stop after about 1–2 minutes; no call in progress |
| Picker choice | **"CallCapture" selected** (single app), not "Share Entire Screen"; picker showed Microphone **On** |
| Observed during capture | Screen: Capturing. Microphone: **Not available — iOS didn't provide this source**. App audio: **Only silence received**. Resource notice ("busy or warm") shown |
| Saved result | 1:55 recording, **Partial**; video plays and begins with the picker on screen; no audio |
| Other | A recording indicator still appeared after Stop (owner report) |

### Findings and fixes (after DT-01)

| ID | Finding | Cause (evidence) | Fix |
|---|---|---|---|
| DT01-1 | No microphone audio although the picker's microphone was on | (a) Microphone permission is requested only from an optional setup step; Start never asked. (b) The engine read the picker's microphone state once; later picker updates during capture were ignored, and the recording shows capture started while the picker was still on screen | Start asks for microphone permission when undetermined; a microphone enabled in a later picker update now gets its output; denied permission is explained with a Settings link |
| DT01-2 | App audio silent | Only CallCapture was shared; a single-app selection cannot include another app's audio (`SCContentFilter.style`) | The app explains before the picker to choose Share Entire Screen, and warns during capture when only one app is shared. `allowedPickerModes` is unavailable on iOS, so the choice can't be forced |
| DT01-3 | Recording indicator after Stop | Live Activity ended only on a final snapshot, which newest-only delivery can skip; ended activities lingered 60 s; activities from earlier runs were never cleaned up | Any inactive state ends the activity immediately; orphan activities end at launch |
| DT01-4 | Owner asked for saving to the Photos gallery | Existed only inside Export | One-tap Save to Photos on the result screen and the player |

Re-test (DT-02) needed on the next build: choose **Share Entire Screen** with Microphone on,
first without a call, then a consented WhatsApp/FaceTime call on speaker (section 19.3 script).
