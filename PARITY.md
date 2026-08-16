# Android → iOS feature parity

Tracks the port of the Android app (`../dealio_android_kotlin`) into this SwiftUI app.

**Out of scope (by request):** push notifications / FCM. The Firebase push wiring
already present (`Networking/PushRegistrar.swift`, the entitlement, `FirebaseMessaging`)
is left as-is and is not being extended. In-app *notification centre screens* are
listed below as ordinary screens — they are a list of rows from an endpoint, not push.

Legend: **✅ done** · **🟡 partial** (screen exists but shallow / mock data / missing
actions) · **⬜ pending** · **⛔ out of scope**

Baseline recorded 2026-08-16. Android side: 184 Kotlin files / ~38.5k lines.
iOS side at baseline: 85 Swift files / ~10k lines.

---

## 0. Foundations (shared, cross-role)

| # | Feature | Android source | iOS status |
|---|---|---|---|
| 0.1 | Deal-stage ladder, aliases, buyer phases, buyer headlines | `ui/flow/DealFlow.kt` | ✅ done — `Flow/DealFlow.swift` |
| 0.2 | The **baton** — who owes the next move, per stage | `ui/flow/DealFlow.kt` | ✅ done — `Flow/DealFlow.swift` |
| 0.3 | Lead ÷ deal split at `Negotiation` (`isLeadStage`/`isDealStage`) | `ui/flow/DealFlow.kt` | ✅ done — `Flow/DealFlow.swift` |
| 0.4 | **Deal spine** — phase track + baton card, one per deal screen | `ui/flow/DealSpine.kt` | ✅ done — `Flow/DealSpine.swift` |
| 0.5 | **Party rail** — 4 threads per deal (3 pairs + group), roster per viewer | `ui/flow/PartyRail.kt` | ✅ done — `Flow/PartyRail.swift` |
| 0.6 | **Stage actions** — what each role may do at each stage | `ui/flow/StageActions.kt` | ✅ done — `Flow/StageActions.swift` |
| 0.7 | **Move queue** — "deals that cannot progress without you", stalled first | `ui/flow/MoveQueue.kt` | ✅ done — `Flow/MoveQueue.swift`, on all three homes |
| 0.8 | **Activity ledger** — what happened on this deal, dotted by actor | `ui/flow/ActivityLedger.kt` | ✅ done — `Flow/ActivityLedger.swift` |
| 0.9 | **Conversation inbox** — one row per *thread* (not per deal), unread counts | `ui/flow/ConversationInbox.kt` | ✅ done — `Flow/ConversationInbox.swift` |
| 0.10 | Thread summaries + read receipts (`POST /threads/summary`, `/threads/read`) | `data/ThreadRepository.kt` | ✅ done — `Networking/ThreadService.swift` |
| 0.11 | Nudge a stalled deal (`POST /deals/:id/nudge`) | `data/api/ThreadApi.kt` | ✅ done — nudge in `Flow/DealRoom.swift` |
| 0.12 | Portal accent — each role's shell lit in its own colour | `ui/components/PortalAccent.kt` | ⬜ pending |
| 0.13 | Profile avatar (view full screen / badge to replace / remove) | `ui/components/ProfileAvatar.kt` | ⬜ pending |
| 0.14 | Avatar endpoints `POST/DELETE /auth/me/avatar` | `data/api/AuthApi.kt` | ⬜ pending |
| 0.15 | Floating pill nav that stays up on nested pages | `ui/components/FloatingPillNav.kt`, the three roots | 🟡 partial — tab bar exists, nested pages push over it |
| 0.16 | Status-bar / safe-area legibility on every screen | `ui/theme/SystemBars.kt` | ✅ done (SwiftUI default + `AuthScaffold`) |
| 0.17 | Splash screen with drawn tagline | `ui/screens/SplashScreen.kt` | ✅ done (`Features/SplashView.swift`) |
| 0.18 | Server-unreachable screen instead of a blocked app | `ui/screens/ServerDownScreen.kt` | ✅ done (`Shared/ServerDownView.swift`) |
| 0.19 | App lock (biometric / PIN) | `ui/screens/AppLockScreen.kt`, `data/AppLockStore.kt` | ✅ done (`Auth/AppLock.swift`, `Features/Auth/LockView.swift`) |
| 0.20 | Share sheet helper | `ui/components/Share.kt` | ✅ done (`Features/Shared/Share.swift`) |
| 0.21 | Meetings calendar component | `ui/components/MeetingsCalendar.kt` | ✅ done (`Features/Shared/MeetingCalendarView.swift`) |

## 1. Auth

| # | Feature | Android source | iOS status |
|---|---|---|---|
| 1.1 | Phone + OTP sign-in | `ui/screens/LoginScreen.kt` | ✅ done |
| 1.2 | Role selector pills on sign-in, hero lit in the role's colour | `ui/components/RoleSelector.kt` | 🟡 partial — dial-code picker landed; role pills still pending |
| 1.3 | Self-serve signup hidden behind a flag | `FeatureFlags.kt` | ✅ done (`AppConfig.signupEnabled`) |
| 1.4 | Phone lookup before OTP (`POST /auth/phone/lookup`) | `data/api/AuthApi.kt` | ⬜ pending |
| 1.5 | Firebase phone auth (`POST /auth/firebase`) | `data/FirebasePhoneAuth.kt` | ⬜ pending |
| 1.6 | Refresh token — an expired access token renews, never ends, the session | `data/TokenStore.kt`, `ui/auth/AuthViewModel.kt` | ⬜ pending |
| 1.7 | Expired session routes to sign-in rather than a dead end | `MainActivity.kt` | ⬜ pending |
| 1.8 | Two-segment details → verify progress track | `ui/components/AuthComponents.kt` | 🟡 partial |

## 2. Builder portal

| # | Feature | Android source | iOS status |
|---|---|---|---|
| 2.1 | Home opens with the move queue, metrics below | `ui/builder/overview/OverviewScreen.kt` | 🟡 partial — move queue landed under the numbers |
| 2.2 | Greeting uses the builder's full name | `ui/builder/overview/OverviewScreen.kt` | 🟡 partial |
| 2.3 | Projects list | `ui/builder/projects/ProjectsScreen.kt` | ✅ done |
| 2.4 | Project detail | `ui/builder/projects/ProjectDetailScreen.kt` | 🟡 partial |
| 2.5 | Project create / edit form + cover-image upload | `ui/builder/projects/ProjectFormScreen.kt` | 🟡 partial — form is a stub |
| 2.6 | Pipeline cut by who owes the next move | `ui/builder/pipeline/PipelineScreen.kt` | ✅ done — stage **and** baton cuts |
| 2.7 | Lead stage moves that actually persist (`PATCH .../leads/:id/stage`) | `ui/builder/pipeline/` | ✅ done |
| 2.8 | Deals list, deal detail with spine + party rail + ledger | `ui/builder/deals/` | ✅ done — shared `DealRoom` |
| 2.9 | Answer a site-visit request (confirm / reschedule / decline) | `ui/builder/meetings/MeetingsScreen.kt` | ✅ done — `MeetingAnswer.swift` |
| 2.10 | Unit matrix | `ui/builder/units/UnitMatrixScreen.kt` | ⬜ pending |
| 2.11 | Commissions + release | `ui/builder/commissions/CommissionsScreen.kt` | 🟡 partial — read-only |
| 2.12 | Shortlists + respond | `ui/builder/shortlists/ShortlistsScreen.kt` | ✅ done — `BuilderShortlistsView` |
| 2.13 | Broadcast | `ui/builder/broadcast/BroadcastScreen.kt` | 🟡 partial |
| 2.14 | CP performance | `ui/builder/cp/CPPerformanceScreen.kt` | 🟡 partial |
| 2.15 | Analytics | `ui/builder/analytics/AnalyticsScreen.kt` | 🟡 partial |
| 2.16 | Loans | `ui/builder/loans/LoansScreen.kt` | 🟡 partial |
| 2.17 | RERA | `ui/builder/rera/ReraScreen.kt` | 🟡 partial |
| 2.18 | Documents | `ui/builder/documents/BuilderDocumentsScreen.kt` | 🟡 partial |
| 2.19 | Demand letters | `ui/builder/demandletters/DemandLettersScreen.kt` | 🟡 partial |
| 2.20 | Possession | `ui/builder/possession/BuilderPossessionScreen.kt` | 🟡 partial |
| 2.21 | Snagging | `ui/builder/snagging/BuilderSnaggingScreen.kt` | 🟡 partial |
| 2.22 | Virtual tours | `ui/builder/virtualtours/VirtualToursScreen.kt` | 🟡 partial |
| 2.23 | AI assistant | `ui/builder/ai/AiAssistantScreen.kt` | 🟡 partial |
| 2.24 | Settings, incl. **Edit** the builder's own profile + avatar | `ui/builder/settings/BuilderSettingsScreen.kt` | ⬜ pending |
| 2.25 | Conversations inbox (per-thread rows, unread badges) | `ui/builder/conversations/` | ✅ done — per-thread rows + unread |
| 2.26 | Notification centre | `ui/builder/notifications/NotificationsScreen.kt` | 🟡 partial |

## 3. Channel-partner portal

| # | Feature | Android source | iOS status |
|---|---|---|---|
| 3.1 | Home: earnings + counts, move queue below | `ui/cp/overview/CpOverviewScreen.kt` | ✅ done — move queue below earnings |
| 3.2 | Partner credential card — portrait, authorisation, partner ID | `ui/cp/CpCredential.kt`, `ui/cp/overview/CpIdentityDialog.kt` | ⬜ pending |
| 3.3 | Leads list + create a lead | `ui/cp/leads/LeadsScreen.kt` | ✅ done — list split + refer a buyer |
| 3.4 | Deals tile lands on the Deals side of the pipeline | `ui/cp/overview/` | ✅ done |
| 3.5 | CP deal detail — spine, party rail, buyer *and* builder threads | `ui/cp/leads/CpDealDetailScreen.kt` | ✅ done — shared `DealRoom` |
| 3.6 | Conversations inbox + thread screen with pinned composer | `ui/cp/conversations/` | 🟡 partial — inbox reworked; dedicated thread screen still pending |
| 3.7 | Contacts: list, add, edit, delete | `ui/cp/contacts/ContactsScreen.kt` | ✅ done — add / edit / delete + dupe warning |
| 3.8 | Contact import from the phone book, deduped | `ui/cp/contacts/ContactImport.kt` | ⬜ pending |
| 3.9 | Full country-code picker | `ui/cp/contacts/CountryCodes.kt` | ✅ done — `Shared/CountryCodes.swift` (172 countries) |
| 3.10 | Follow-ups: list, create, mark done | `ui/cp/followups/FollowUpsScreen.kt` | ✅ done — create + swipe-done |
| 3.11 | Call logs | `ui/cp/calllogs/CallLogsScreen.kt` | ⬜ pending |
| 3.12 | Meetings + arrange a site meeting (not just read them) | `ui/cp/meetings/CpMeetingsScreen.kt` | 🟡 partial |
| 3.13 | Book a site visit straight from a lead | `ui/cp/leads/CpDialogs.kt` | ⬜ pending |
| 3.14 | **Meetups**: list | `ui/cp/meetups/CpMeetupsScreen.kt` | ⬜ pending |
| 3.15 | **Meetups**: create / edit form incl. photo upload | `ui/cp/meetups/CpMeetupFormScreen.kt` | ⬜ pending |
| 3.16 | **Meetups**: event page + invite list + cancel | `ui/cp/meetups/CpMeetupDetailScreen.kt` | ⬜ pending |
| 3.17 | **Meetups**: invite picker over contacts/leads | `ui/cp/meetups/InvitePicker.kt` | ⬜ pending |
| 3.18 | Meetup vocabulary (category, mode, RSVP words + colours) | `ui/meetups/MeetupVocabulary.kt` | ⬜ pending |
| 3.19 | Projects list + project detail (shared with customer detail) | `ui/cp/projects/` | ✅ done |
| 3.20 | Flyer generator with the tracked link burned in as a QR | `ui/cp/growth/Flyer.kt` | ⬜ pending |
| 3.21 | Caption variants written around the offer | `ui/cp/growth/CaptionVariants.kt`, `OfferTypes.kt` | 🟡 partial |
| 3.22 | Content studio | `ui/cp/growth/ContentStudioScreen.kt` | 🟡 partial |
| 3.23 | Brochure | `ui/cp/growth/BrochureScreen.kt` | 🟡 partial |
| 3.24 | WhatsApp broadcast | `ui/cp/growth/WhatsAppBroadcastScreen.kt` | 🟡 partial |
| 3.25 | Referral | `ui/cp/growth/ReferralScreen.kt` | 🟡 partial |
| 3.26 | Leaderboard | `ui/cp/growth/LeaderboardScreen.kt` | 🟡 partial |
| 3.27 | AI insights | `ui/cp/growth/AiInsightsScreen.kt` | 🟡 partial |
| 3.28 | Social analytics | `ui/cp/growth/SocialAnalyticsScreen.kt` | 🟡 partial |
| 3.29 | Community / JV | `ui/cp/growth/CommunityJvScreens.kt` | 🟡 partial |
| 3.30 | Loan assist | `ui/cp/loan/CpLoanAssistScreen.kt` | 🟡 partial |
| 3.31 | Profile — portrait, photo change, authorisation + ID under it | `ui/cp/profile/CpProfileScreen.kt` | 🟡 partial |
| 3.32 | More page led by the partner's own account | `ui/cp/more/CpMoreScreen.kt` | 🟡 partial |
| 3.33 | Notification centre | `ui/cp/notifications/CpNotificationsScreen.kt` | ⬜ pending |
| 3.34 | Share a project with a tracked link (`POST .../share-link`) | `ui/cp/projects/` | ⬜ pending |

## 4. Customer portal

| # | Feature | Android source | iOS status |
|---|---|---|---|
| 4.1 | Explore — cities, search, project cards | `ui/customer/explore/ExploreScreen.kt` | ✅ done |
| 4.2 | Project detail (1.6k lines: gallery, EMI slider, specs, plans, advantages) | `ui/customer/project/ProjectDetailScreen.kt` | 🟡 partial |
| 4.3 | EMI slider reaches the top of the price band | `ui/customer/project/` | ⬜ pending |
| 4.4 | Bookmark on every project + a shelf to keep it on | `ui/customer/saved/SavedScreen.kt` | ✅ done — `SavedProjectsStore` |
| 4.5 | Saved-projects endpoints (`GET/POST/DELETE /customer/saved-projects`) | `data/api/CustomerApi.kt` | ✅ done |
| 4.6 | Visits list, not clipped above the bottom nav | `ui/customer/visits/VisitsScreen.kt` | 🟡 partial |
| 4.7 | Open a site visit and see where it is | `ui/customer/visits/VisitsScreen.kt` | ⬜ pending |
| 4.8 | Don't offer a visit that is already on the books | `ui/customer/project/` | ⬜ pending |
| 4.9 | Rate a completed visit (`PATCH /portal/customer/meetings/:id/rating`) | `ui/customer/visits/` | ⬜ pending |
| 4.10 | Booked slots when picking a visit time | `data/api/CustomerApi.kt` | ⬜ pending |
| 4.11 | Journey — five buyer phases, buyer-safe copy | `ui/customer/journey/JourneyScreen.kt` | ✅ done — phase track + buyer headline |
| 4.12 | Customer deal detail with spine + party rail | `ui/customer/journey/DealDetailScreen.kt` | ✅ done — `CustomerDealRoomView` |
| 4.13 | Accept a negotiation / confirm a deal | `data/api/CustomerApi.kt` | ⬜ pending |
| 4.14 | Messaging handed off to Conversations, as the CP page does | `ui/customer/conversations/` | 🟡 partial |
| 4.15 | Profile — set and remove a picture | `ui/customer/profile/ProfileScreen.kt` | ⬜ pending |
| 4.16 | Preferred city | `data/api/CustomerApi.kt` | ⬜ pending |
| 4.17 | **Meetups** — always-there way in, list, event page, RSVP | `ui/customer/meetups/` | ⬜ pending |
| 4.18 | Meetups strip (off the projects page) | `ui/customer/meetups/MeetupsStrip.kt` | ⬜ pending |
| 4.19 | Loans: list, apply, eligibility, EMI calculator | `ui/customer/loan/` | 🟡 partial — static |
| 4.20 | Top-up, investments | `ui/customer/finance/` | 🟡 partial — static |
| 4.21 | Possession + snagging | `ui/customer/handover/` | 🟡 partial — static |
| 4.22 | Property page | `ui/customer/property/PropertyScreen.kt` | 🟡 partial |
| 4.23 | Documents | `ui/customer/documents/DocumentsScreen.kt` | 🟡 partial |
| 4.24 | Support / contact | `ui/customer/support/CustomerContactScreen.kt` | 🟡 partial |
| 4.25 | Notification centre | `ui/customer/notifications/` | ⬜ pending |
| 4.26 | Pricing requests (`POST /portal/customer/pricing-requests`) | `data/api/CustomerApi.kt` | ⬜ pending |

## 5. Excluded

| # | Feature | Reason |
|---|---|---|
| 5.1 | FCM push service, device-token registration, notification channels | ⛔ out of scope by request |
| 5.2 | Android-only integrations (phone-book read, call log read, `ACTION_INSERT` calendar) | Platform equivalents noted per-row above where a feature depends on them |

---

## Order of work

1. Foundations 0.1–0.11 — the deal-flow core everything else renders against.
2. Builder 2.1/2.6/2.7/2.8/2.9 — the pipeline actually moving.
3. CP 3.1–3.13 — leads, contacts, follow-ups, meetings.
4. Customer 4.4/4.7/4.11/4.12/4.15 — saved, visits, journey.
5. Meetups end-to-end (3.14–3.18, 4.17–4.18).
6. The remaining 🟡 screens, deepest-first.

## Notes on the port

This is not a transliteration. Where the Android shape doesn't fit iOS, or where
the Android code has a defect, the iOS version differs on purpose:

- **One `DealRoom` for three roles.** Android has a separate deal screen per
  portal; iOS has one, parameterised by `viewer`. The buyer had no deal screen on
  either platform before this.
- **`relativeDay` actually formats.** Android's ledger documented "today / 3d"
  and returned the raw `yyyy-MM-dd`.
- **`daysSince` returns `Int?`.** "We don't know" no longer sorts as "touched
  today" in the move queue.
- **`APIClient.call`** for the many Dealio writes that answer `{ ok: true }` with
  no `data` — those previously had to be issued as a typed request whose decode
  error the caller then swallowed.
- **The stage table is built statement-by-statement**, because Swift type-checks
  a nested dictionary literal that size exponentially.
- **The dial-code picker reaches sign-in too**, which on Android it does not: the
  iOS code field was free text that accepted any five characters.
- **Payload de-duplication** — `BookMeetingRequest` had a second private copy
  inside the project page.

## Verified

Every commit builds clean (`xcodebuild … -destination 'iPhone 17'`) and the app
was installed and launched on the simulator against the live dev backend, signed
in as a builder, a CP and a customer in turn. Screens confirmed rendering against
real data: sign-in (dial-code picker), builder Overview (move queue, baton copy,
staleness), CP Overview (move queue, stalled-first ordering, lead/deal counts),
customer Explore (bookmarks, saved state restored from the server).

Not confirmed by tapping through: the deal room, the visit-answer sheet, the CRM
forms and the pipeline's stage moves. macOS refused this session permission to
send Apple events to the Simulator, so there was no way to drive the UI; those
are verified by compile and by their models' endpoints only.

## Changelog

<!-- Newest first. One line per landed commit. -->
- `4737019` customer: a bookmark on every project, and a shelf that holds them
- `364c003` cp: refer a buyer, and stop counting one row as both a lead and a deal
- `f15d1ed` cp: a CRM that can be written to, and the rest of the world in the picker
- `6aed784` pipeline: cut the same leads by who owes the next move
- `d0a183a` builder: answer a visit request instead of only reading it
- `22bc82b` home: open on the deals that cannot move without you
- `00250fa` deals: one deal room for all three roles, and an inbox per thread
- `617e882` flow: teach iOS the deal ladder, the baton, and the four threads
- `cd4b769` parity: write down what the iOS app still owes the Android one
