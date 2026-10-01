# Blockers and owner-dependent items

Items here need the owner's access, hardware, accounts or a decision. Unrelated implementation continues meanwhile.

| ID | Needed from owner | What it blocks | Status |
|---|---|---|---|
| B01 | Apple Developer Program membership, App Store Connect app record, final bundle identifier (currently provisional `com.adnanzulfiqar.callcapture`), signing approach (local Mac or CI with protected secrets) | P13 signed archive, TestFlight (M2) | OPEN — not needed until M1 |
| B02 | Physical iPhone on iOS 27 plus willing test participants for WhatsApp/FaceTime calls (speaker and AirPods) | P14 device validation (M3) | OPEN — by design after M1 + M2 |
| B03 | Independent reviewer (Cursor) access to the repository | Independent acceptance of P00–P12 | OPEN — recorded as INDEPENDENT_REVIEW_PENDING; does not block development |
| B04 | Pro product decision: price tier and final product ID (`com.adnanzulfiqar.callcapture.pro` is provisional) | App Store Connect in-app purchase setup (P13/P16) | OPEN — StoreKit test configuration used until then |
| B05 | Privacy-policy and support URLs | App Store submission (P16) | OPEN |

## Technical risks being tracked (not blockers)

| ID | Risk | Mitigation |
|---|---|---|
| R-SCK-01 | `xcode-27` runner is a GitHub preview image | If it disappears, record BUILD_VERIFICATION_BLOCKED; no substitution with iOS 26 SDK (no ScreenCaptureKit there) |
| R-AUD-01 | `.playAndRecord` + `.mixWithOthers` session may affect a live call | Assessed in P14; no route-changing options are used |
| R-AUD-02 | Remote VoIP call audio may not be delivered (S14) | UI shows app audio as unconfirmed until it arrives; never claims both participants |
