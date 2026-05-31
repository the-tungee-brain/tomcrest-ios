# Tomcrest iOS

Native SwiftUI companion app for [Tomcrest](https://tomcrest.com) — AI portfolio intelligence backed by the `stock-analysis` API.

## Requirements

- Xcode 16+ (iOS 17 deployment target)
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the Xcode project from `project.yml`

## Getting started

1. Open `Tomcrest.xcodeproj` in Xcode.
2. Select the **Tomcrest** scheme and an iOS Simulator.
3. Build and run (`⌘R`).

## Configuration (before sign-in)

### 1. Create Google iOS OAuth client

In [Google Cloud Console](https://console.cloud.google.com/) (same project as the web app):

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**
2. Application type: **iOS**
3. Bundle ID: `com.tomcrest.app`
4. Copy the **iOS client ID** and **iOS URL scheme** (reversed client ID)

### 2. Update `Tomcrest/Config/AppConfig.swift`

| Constant | Value |
|----------|--------|
| `googleClientID` | iOS OAuth client ID |
| `googleReversedClientID` | iOS URL scheme from Google Console |
| `googleServerClientID` | Web client ID (already set — matches backend `GOOGLE_CLIENT_ID`) |

The `serverClientID` makes Google return an ID token whose audience matches your backend, so no API changes are needed.

### 3. Update `Tomcrest/Info.plist`

Replace the URL scheme placeholder with your **reversed client ID** (must match `googleReversedClientID`):

```xml
<string>com.googleusercontent.apps.YOUR-IOS-CLIENT-SUFFIX</string>
```

## Architecture

```
Tomcrest/
├── App/           Root + tab navigation (Portfolio / Research / Settings)
├── Auth/          Session, Keychain JWT storage, sign-in UI
├── Config/        API base URL + OAuth placeholders
├── Design/        Colors aligned with web app
├── Features/      Screen placeholders per MVP phases
├── Models/        Codable DTOs
└── Networking/    APIClient (Bearer auth, waitlist + Schwab reauth errors)
```

## MVP phases

| Phase | Status | Scope |
|-------|--------|--------|
| 0 | **Done** | Project shell, tabs, API client, Keychain, auth placeholders |
| 1 | **Done** | Google Sign-In SDK → `POST /auth/google/callback` |
| 2 | **Done** | Schwab OAuth via `ASWebAuthenticationSession` |
| 3 | **Done** | Portfolio Today (morning brief, alerts, positions) |
| 4 | **Done** | Streaming portfolio AI chat |
| 5 | **Done** | Symbol search + overview |
| 6 | **Done** | Settings polish (plan card, delete account, security links) |
| 7 | **Done** | Research symbol AI chat (`POST /research/chat`) |
| 8 | **Done** | Chat markdown + history hydration + strategy settings |
| 9 | **Done** | Research depth tabs (earnings, news, dividends, fundamentals) |
| 10 | **Done** | Earnings detail + Pro AI analysis (`GET /research/earnings/detail`) |
| 11 | **Done** | Strategy journey checklist in Settings |
| 12 | **Done** | Chat model picker (Pro/Free tiers) |
| 13 | **Done** | TestFlight prep docs + export compliance |
| UI | **Done** | Portfolio, Research, Settings design passes |

## Schwab OAuth (Phase 2)

1. Sign in with Google.
2. Open **Settings → Connect Schwab**.
3. Complete Schwab login in the in-app browser.
4. On success, the app receives `tomcrest://schwab?status=success`.

The iOS app calls `GET /auth/schwab/connect?client=ios`. The backend redirects iOS OAuth completions to `tomcrest://schwab` instead of the web frontend. Override with env var `POWERPOCKET_IOS_OAUTH_REDIRECT_URI` if needed.

Deploy the backend changes in `stock-analysis` before testing Schwab connect on iOS.

## Regenerate Xcode project

```bash
xcodegen generate
```

## Apple Developer

Not required for Simulator development. Enroll ($99/yr) when you need a physical device, TestFlight, or App Store release.

See **[docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)** for archive, upload, and App Store Connect checklist.

## Related repos

- Web: `my-pocket`
- API: `stock-analysis`
# tomcrest-ios
