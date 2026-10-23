# Device builds and testing (P13 → P14)

CallCapture is a native SwiftUI app (XcodeGen + Xcode 27). It is built on the GitHub `xcode-27`
runner by `.github/workflows/device-build.yml`. Expo / EAS Build is not used: EAS builds
React Native and Expo projects, and this repository has no JavaScript app to build.

Requirement: the iPhone must run **iOS 27** (deployment target; ScreenCaptureKit exists only in the iOS 27 SDK).

## Route A — TestFlight (recommended; roadmap P13)

### One-time setup by the owner (≈15 minutes)

1. **App Store Connect API key.** App Store Connect → Users and Access → Integrations →
   App Store Connect API → Team Keys → **Generate API Key**, access **Admin**
   (Admin lets Xcode create the signing certificate, App IDs and profiles automatically).
   Download the `.p8` file (only downloadable once). Note the **Key ID** and **Issuer ID**.
2. **Team ID.** developer.apple.com → Account → Membership details → Team ID (10 characters).
3. **App record.** App Store Connect → Apps → **+ New App**: platform iOS, name *CallCapture*
   (or the final name), bundle ID `com.adnanzulfiqar.callcapture`, SKU of your choice.
   If the bundle ID is not listed yet, run the workflow once (step 5) — automatic signing
   registers it — then create the app record and run again.
   If you want a different final bundle ID (BLOCKERS B01), say so before the first upload;
   it changes `project.yml` for the app and the `.widgets` extension.
4. **GitHub secrets.** Repository → Settings → Environments → **New environment** `signing`
   (optionally add yourself as required reviewer), then add environment secrets:

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID` | Key ID from step 1 |
   | `ASC_ISSUER_ID` | Issuer ID from step 1 |
   | `ASC_KEY_P8` | Full text of the `.p8` file, including the `BEGIN`/`END` lines |
   | `APPLE_TEAM_ID` | Team ID from step 2 |

   Never paste these values into an issue, PR, commit or chat.

### Each build

5. Actions → **Device build** → Run workflow → tick *Also produce a signed IPA*, method
   `app-store-connect`. (Before the workflow is on the default branch, push a tag instead:
   `git tag testflight-1.0.0-1 <commit> && git push origin testflight-1.0.0-1`.)
6. The job archives, signs, runs the release audit on the signed app, and uploads.
   Apple processes the build (usually 5–30 minutes).
7. App Store Connect → TestFlight → add yourself to an **Internal Testing** group
   (no Beta App Review needed for internal testers). Install **TestFlight** on the iPhone and accept.
8. Record the build from the run's `BUILD_RECORD.txt` artifact in the device evidence record.

## Route B — ad hoc IPA (no TestFlight)

Register the iPhone's UDID at developer.apple.com → Devices, then run the workflow with method
`release-testing`. Download the `CallCapture-signed-ipa-*` artifact and install with Apple
Configurator (Mac) or Finder/Apple Devices (drag the IPA onto the device). Only registered
devices can install it.

## Unsigned IPA (every push)

Each code push produces `CallCapture-unsigned-ipa-<run>` (Release build, release audit,
`BUILD_RECORD.txt`). It cannot be installed as-is; it is for re-signing tools and inspection.
A re-signed build is **not** the TestFlight binary: record it as such in any evidence.

## After installation — P14

Follow roadmap section 19: evidence record (19.1), execution order (19.2), controlled call
script (19.3) and release-scope matrix (19.4). Every result — pass, fail, unsupported,
inconclusive — is recorded against the exact build in `BUILD_RECORD.txt`.

## Troubleshooting

| Symptom in the run log | Cause / fix |
|---|---|
| `DISTRIBUTION_BLOCKED … missing secrets` | Step 4 incomplete or secrets added to the repository instead of the `signing` environment |
| `No profiles for 'com.adnanzulfiqar.callcapture'` / cannot create certificate | API key access is not Admin, or the bundle ID belongs to another team |
| Upload: `No suitable application records were found` | App record (step 3) missing or bundle ID differs |
| Upload: `The bundle version must be higher` | Re-run: the build number is the workflow run number and always increases |
