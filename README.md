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

Edit `Tomcrest/Config/AppConfig.swift`:

| Constant | Value |
|----------|--------|
| `googleClientID` | Google Cloud **iOS** OAuth client ID for bundle `com.tomcrest.app` |
| `apiBaseURL` | Already points to production (`thetungeebrain.duckdns.org`) |

After creating the Google iOS client, also update `Tomcrest/Info.plist`:

- `GOOGLE_REVERSED_CLIENT_ID` → reversed client ID (URL scheme for Google Sign-In callback)

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
| 1 | Next | Google Sign-In SDK → `POST /auth/google/callback` |
| 2 | Planned | Schwab OAuth via `ASWebAuthenticationSession` |
| 3 | Planned | Portfolio Today (morning brief, alerts, positions) |
| 4 | Planned | Streaming AI chat |
| 5 | Planned | Symbol search + overview |
| 6 | Planned | Settings (disconnect, account plan) |

## Regenerate Xcode project

```bash
xcodegen generate
```

## Apple Developer

Not required for Simulator development. Enroll ($99/yr) when you need a physical device, TestFlight, or App Store release.

## Related repos

- Web: `my-pocket`
- API: `stock-analysis`
# tomcrest-ios
