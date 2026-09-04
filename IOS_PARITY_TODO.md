# iOS parity — what's left

Tracks the Android app (`dealio_android_kotlin`) against the iOS app
(`ios/dealio_ios`). Everything not listed here has been ported and builds.

Line counts are a rough proxy for depth, not a target — several iOS screens are
deliberately shorter because SwiftUI expresses the same thing in less code (the
analytics chart, for instance, is Swift Charts against Android's hand-drawn
bars). They are given only where iOS is genuinely missing behaviour.

Last audited: 2026-09-03. iOS is 126 files / ~25,900 lines; Android is
185 files / ~39,700 lines.

---

## 1. Blocking — needs someone with account access

### Firebase config is wrong for this bundle
`GoogleService-Info.plist` declares `BUNDLE_ID = com.winday.dealio`, but the
target builds `com.dealio.builder`. It also has no `CLIENT_ID` /
`REVERSED_CLIENT_ID`.

Consequences:
- **FCM push may not deliver.** `FirebaseApp.configure()` accepts the mismatch
  with a console warning, but the APNs-token → FCM-token mapping is registered
  against the plist's bundle id. This affects push that is *already shipped*.
- **Firebase phone auth cannot be added** until this is fixed. It needs the
  reversed client id as a URL scheme for its reCAPTCHA fallback, and a matching
  App ID with Push enabled for the silent-APNs path.

Fix: decide which bundle id is authoritative, re-download
`GoogleService-Info.plist` for it from the Firebase console, and confirm the iOS
app there has Phone as a sign-in provider and an APNs key uploaded.

### Push entitlement is empty
`DealioBuilder/DealioBuilder.entitlements` is `<dict/>`. There is no
`aps-environment`, so remote push will not be delivered to a device build even
once the plist above is corrected. Add `aps-environment: development` once the
App ID has the Push Notifications capability.

---

## 2. Auth mechanism differs (working, but not the same as Android)

Android sends the login OTP **from the device via Firebase phone auth**, then
exchanges the Firebase ID token at `POST /auth/firebase` for a Dealio session.

iOS uses the **backend OTP** route instead:
`/auth/login/phone/send-otp` → `/auth/login/phone/verify-otp`.

This is functional and has parity on everything around it — role pills, the
`/auth/phone/lookup` pre-flight, the mismatched-role one-tap correction. Only
the delivery mechanism differs. Switching it over is blocked on §1.

---

## 3. Screens that exist on iOS but are thinner than Android

All of these render, load real data where an endpoint exists, and are reachable
from a menu. They are listed in the order I'd do them.

| Screen | iOS | Android | What iOS is missing |
|---|---:|---:|---|
| `CustomerPropertyView` | 59 | 163 | Per-property detail: possession milestones, documents count, and the link into the deal room. Currently one card per booking. |
| `CPSocialAnalyticsView` | 87 | 196 | Per-platform breakdown and the engagement trend; iOS shows totals only. |
| `BuilderVirtualToursView` | 82 | 132 | Per-project tour embed and the "no tour yet" prompt to add one on the project form. |
| `BuilderBroadcastView` | 84 | 150 | Audience picker (CPs / customers / both) and the delivered-count history list. |
| `BuilderAIView` | 94 | 210 | The canned prompt set and the per-answer source citations. Note: there is **no AI endpoint** — both apps derive answers locally. |
| `CPLoanAssistView` | 85 | 152 | Bank comparison table and the eligibility hand-off into the buyer's loan application. |
| `CPLeaderboardView` | 105 | 189 | Tier progress ring and the monthly-goal tracker. |
| `CustomerContactView` | 106 | 198 | Support-topic picker and the FAQ accordion; iOS shows contact channels only. |
| `CPAIInsightsView` | 142 | 224 | Per-lead scoring rationale and the suggested next action per row. |
| `CPCommunityJVViews` | 67 | 134 | Both screens are placeholders on Android too — parity here means matching two "coming soon" states, so this is the lowest-value item on the list. |

**None of these have a backend endpoint behind them.** Every figure is derived
client-side from projects / leads / deals / profile, which is why they were
deprioritised: the work is presentational, and the numbers already agree with
the lists they came from.

---

## 4. Known platform differences (deliberate, not gaps)

- **Deep links** — Android resolves a notification's `link` through
  `ui/navigation/DeepLink.kt`; iOS mirrors it in `Domain/DeepLink.swift` and
  routes through `PortalRouter`. Behaviour matches, wiring differs.
- **Flyer export** — Android captures a Compose `GraphicsLayer`; iOS renders the
  same 1080×1350 poster through `ImageRenderer`. Same output.
- **WhatsApp broadcast batching** — iOS opens 3 chats per tap and removes them
  from the selection. Android opens 3 too, but iOS drops queued `openURL` calls
  when the app switches away, so the batching is surfaced in the copy.
- **Spreadsheet import** — both read `.xlsx` without a third-party library.
  Android parses the zip with `ZipInputStream` + `android.util.Xml`; iOS uses a
  minimal ZIP central-directory reader over `Compression` plus `XMLParser`
  (`Shared/Spreadsheet.swift`). Verified against a generated workbook.

---

## 5. Housekeeping

- `DealioBuilder 2.xcodeproj` and `DealioBuilder 3.xcodeproj` are stale Finder
  duplicates and do **not** contain the files added since. The project is
  generated: `xcodegen generate` → open `DealioBuilder.xcodeproj`
  (git-ignored by design, see `.gitignore`).
- `project.yml` has `DEVELOPMENT_TEAM: ""`. Device builds need
  `DEVELOPMENT_TEAM=622PYKY2SY` passed on the command line, or the field filled
  in.
- Running on a device also needs the developer profile trusted once, on the
  phone: **Settings → General → VPN & Device Management → Apple Development:
  veeravenkata.pusuluri@gmail.com → Trust**.
