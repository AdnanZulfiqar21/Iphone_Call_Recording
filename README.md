# CallCapture — iPhone recording app

Native Swift/SwiftUI iPhone app (iOS 27+) that helps a person deliberately record available screen and audio, see honest per-source recording health, recover interrupted recordings, and manage a local library.

**Status:** In development (roadmap phases P00–P12). Nothing here claims call recording works on a physical iPhone; that is only established by device testing (phase P14), after the complete build and a TestFlight build. See [progress](docs/execution/PROGRESS.md).

## Layout

| Path | Contents |
|---|---|
| `Packages/CallCaptureCore/Sources/CallCaptureCore` | Platform-light domain core: contracts, lifecycle state machine, session controller, health/anomaly ledger, bounded ingress, store, recovery, deletion, migrations, diagnostics, resource governor, library query, status copy mapping, entitlements |
| `Packages/CallCaptureCore/Sources/CallCaptureMedia` | ScreenCaptureKit capture engine (iOS 27), segmented AVAssetWriter backend, assembler, validator, audio analysis |
| `App/` | SwiftUI app: design system, Record/Recordings/Settings, player, export, Pro, app lock, Live Activity projection |
| `Widgets/` | Live Activity widget extension |
| `AppTests/`, `UITests/` | App unit tests and simulator UI flows with explicitly simulated capture |
| `project.yml` | XcodeGen spec (the Xcode project is generated, not committed) |
| `scripts/` | Asset generation, contrast check, release audit |
| `docs/` | Roadmap, platform decision, UX design system and acceptance, execution records, reviews |

## Build and test

Core logic (any machine with Docker):

```bash
docker run --rm -v "$PWD/Packages/CallCaptureCore:/pkg" -w /pkg swift:6.2 swift test --build-path /tmp/build
```

App (macOS with Xcode 27 and XcodeGen):

```bash
xcodegen generate && xcodebuild test -project CallCapture.xcodeproj -scheme CallCapture -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

CI (`.github/workflows/ci.yml`) runs Linux core tests, macOS package tests with an iOS 27 device-SDK compile, and the app's simulator tests plus an unsigned Release device build with a release audit.

## Key documents

- [Development roadmap v2.2](docs/roadmap/CallCapture_Development_Roadmap_v2_Build_First.md) and [review](docs/roadmap/ROADMAP_REVIEW_v2.2.md)
- [Capture path decision (P01)](docs/platform/capture-path-decision.md)
- [Design system](docs/ux/design-system.md), [contrast report](docs/ux/contrast-report.md), [UX acceptance](docs/ux/ui-acceptance.md), [mockup](docs/ux/mockups/callcapture-ui-mockup.html)
- [Autonomous build authorization](docs/execution/AUTONOMOUS_BUILD_AUTHORIZATION.md), [blockers](docs/execution/BLOCKERS.md), [resume state](docs/execution/RESUME_STATE.md), [review index](docs/reviews/CURSOR_REVIEW_INDEX.md)

Delivery order: complete app build → signed TestFlight build → physical iPhone testing → fixes and retest → release.
