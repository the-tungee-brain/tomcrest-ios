# TestFlight release checklist

Use this when you're ready to ship Tomcrest iOS to internal testers.

## Prerequisites

1. **Apple Developer Program** ($99/yr) — [developer.apple.com/programs](https://developer.apple.com/programs/)
2. **App Store Connect app record** with bundle ID `com.tomcrest.app`
3. **Google iOS OAuth client** configured (see main README)
4. **Backend live** with iOS Schwab redirect (`tomcrest://schwab`) deployed

## Xcode project setup

1. Open `Tomcrest.xcodeproj` → Tomcrest target → **Signing & Capabilities**
2. Set **Team** to your Apple Developer team (also add `DEVELOPMENT_TEAM` in `project.yml` if using XcodeGen)
3. Confirm **Bundle Identifier**: `com.tomcrest.app`
4. Bump **Marketing Version** (`MARKETING_VERSION`) for user-visible releases
5. Bump **Build** (`CURRENT_PROJECT_VERSION`) for every upload

```bash
xcodegen generate   # if you changed project.yml
```

## Archive & upload

1. Select **Any iOS Device (arm64)** as run destination (not Simulator)
2. **Product → Archive**
3. In Organizer: **Distribute App → App Store Connect → Upload**
4. Wait for processing in App Store Connect (typically 5–30 minutes)

## App Store Connect metadata (minimum)

| Field | Suggested value |
|-------|-----------------|
| Name | Tomcrest |
| Subtitle | AI portfolio intelligence |
| Category | Finance |
| Privacy Policy URL | Same as web (`AppConfig.privacyURL`) |
| Support URL | Same as web support link |

### App Privacy

Declare data collected consistent with the web app:

- **Contact info** — email (account sign-in)
- **Financial info** — portfolio holdings via read-only Schwab OAuth (not stored on device beyond session)
- **Identifiers** — user ID for authentication

No third-party advertising or tracking in the iOS app.

### Export compliance

The app uses standard HTTPS only. `ITSAppUsesNonExemptEncryption` is set to **NO** in `project.yml`.

## TestFlight testing

1. App Store Connect → **TestFlight** → add internal testers (team members)
2. Verify flows:
   - Google Sign-In
   - Schwab connect / disconnect
   - Portfolio Today + chat (model picker)
   - Research symbol tabs + earnings AI (Pro account)
   - Settings strategy + journey checklist
3. Add **What to Test** notes for each build

## Common blockers

| Issue | Fix |
|-------|-----|
| Missing URL scheme | Update `Info.plist` Google reversed client ID |
| Schwab redirect fails | Deploy backend iOS redirect; test `client=ios` |
| Pro features locked | Confirm `/account/plan` returns correct `isPaid` / `features` |
| Archive signing error | Set Development Team; enable Automatic Signing |

## Related

- Main setup: [README.md](../README.md)
- API: `stock-analysis` repo
- Web reference: `my-pocket` repo
