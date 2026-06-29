# Dealio Builder — iOS

A native **SwiftUI** iOS app for the Dealio **Builder** module, talking to the same
Node/Express backend as the web app. This is the first slice: only the **builder**
role is implemented (login + overview + projects + leads + deals).

> Built with Swift + SwiftUI, no third-party dependencies.

## Requirements

- **Full Xcode 15 or newer** (for the iOS 17 SDK and a simulator). The machine this was
  scaffolded on only had the Command Line Tools, so the app was **not compiled here** —
  open it in Xcode to build and run.
- The Dealio backend running locally on **port 8090** (`cd Dealio_Backend && npm run dev`).

## Open & run

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
A generated `DealioBuilder.xcodeproj` is already included, so you can just open it:

```bash
open Dealio_iOS/DealioBuilder.xcodeproj
```

If you change `project.yml` or add files, regenerate:

```bash
brew install xcodegen        # once
cd Dealio_iOS
xcodegen generate
```

Then in Xcode: select an **iPhone simulator** and press **⌘R**.

To build/run from the command line once full Xcode is installed:

```bash
cd Dealio_iOS
xcodebuild -project DealioBuilder.xcodeproj -scheme DealioBuilder \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Backend connection

- The base URL lives in **`DealioBuilder/Config/AppConfig.swift`** → `apiBaseURL`
  (default `http://localhost:8090/api`).
- The **iOS Simulator** shares the Mac's network, so `localhost` reaches your backend.
- On a **physical device**, change `apiBaseURL` to your Mac's LAN IP
  (e.g. `http://192.168.1.10:8090/api`) and keep both on the same Wi-Fi.
- App Transport Security is configured in `Info.plist` to allow plain HTTP to the local
  backend (`NSAllowsLocalNetworking` / `NSAllowsArbitraryLoads`) — relax these for a
  production HTTPS endpoint.

## Sign in

Phone + OTP, same as the web app. Outside production the backend accepts the dev code
**`123456`** (and echoes a demo code in the response, shown on the OTP screen). A new
phone number is provisioned as a `BUILDER`; the app then calls `/builder/ensure` to
resolve the builder profile id used by the `/builder/:id/...` endpoints.

## What's implemented (builder module)

| Screen | Backend |
|---|---|
| **Login** | `POST /auth/signup/phone/send-otp`, `…/verify-otp` |
| **Overview** | counts + pipeline from projects/leads/deals |
| **Projects** + detail | `GET /builder/:id/projects` |
| **Leads** | `GET /builder/:id/leads` |
| **Deals** | `GET /builder/:id/deals` |

Pull-to-refresh on every list. Read-only for now (no create/edit yet).

## Project layout

```
DealioBuilder/
  DealioBuilderApp.swift      App entry, injects AuthStore
  Config/AppConfig.swift      Base URL + brand colour
  Networking/                 APIClient (envelope + bearer), APIError
  Models/Models.swift         Codable: AuthUser, Project, Lead, Deal
  Auth/AuthStore.swift        Session + phone-OTP flow + ensureBuilder
  Shared/Components.swift      StatCard, StatusBadge, ErrorBanner, Money
  Features/
    RootView, MainTabView
    Auth/LoginView
    Overview/OverviewView
    Projects/ProjectsView, ProjectDetailView
    Leads/LeadsView
    Deals/DealsView
```

## Notes / next steps

- The access token is stored in `UserDefaults` for simplicity — move it to the **Keychain**
  for production.
- Only the builder module is built. CP / customer / admin and write actions (add project,
  update lead stage, deal chat) are future work.
- Generated `*.xcodeproj` is git-ignored on the assumption you regenerate from `project.yml`;
  delete that line from `.gitignore` if you'd rather commit it.
