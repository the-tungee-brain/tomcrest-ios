# Tomcrest iOS architecture

## Principles

- **Features own screens** — ViewModels, services, and UI live together under `Features/`.
- **DesignSystem is shared** — Tokens, components, and layout shells are reused everywhere.
- **Thin navigation** — Tab roots use `NavigationStack`; Settings pushes detail screens instead of stacking disclosures on one scroll.

## Folder layout

```
Tomcrest/
├── App/                    Entry point & shell
│   ├── TomcrestApp.swift
│   ├── RootView.swift
│   └── MainTabView.swift
│
├── DesignSystem/           Shared UI (formerly UI/)
│   ├── Components/         Buttons, lists, chat, formatters
│   ├── Design/             Tokens, panels, typography, layout
│   └── Navigation/         Scroll shells, tab bars
│
├── Core/
│   ├── Auth/               Sign-in, tokens, Schwab OAuth
│   ├── Config/             API URLs, legal links
│   ├── Models/             API & domain types
│   └── Networking/         API client, streaming, chat service
│
└── Features/
    ├── Portfolio/          Today, holdings, playbook, analysis
    ├── Research/           Hub, symbol depth tabs, watchlist
    ├── Settings/           Hub + pushed detail screens
    │   ├── Navigation/     SettingsDestination routes
    │   ├── Components/     Hub list style + shared cards
    │   ├── Screens/        Brokerage, Strategy, Account, Legal, About
    │   └── SettingsView.swift
    └── Onboarding/         First-run cards & wizard
```

## Settings navigation

| Hub row | Screen | Contents |
|---------|--------|----------|
| Brokerage | `BrokerageSettingsScreen` | Schwab connect/disconnect |
| Strategy | `StrategySettingsScreen` | Playbook editor, preferences, journey checklist |
| Account & plan | `AccountSettingsScreen` | Identity, plan features, delete account |
| Legal | `LegalSettingsScreen` | Privacy, terms, security links |
| About | `AboutSettingsScreen` | Version, support |

Deep link from Portfolio: `SettingsFocus.strategy` pushes the Strategy screen.

## Adding a feature

1. Create `Features/<Name>/` with ViewModel + Service + views.
2. Add a thin tab root under `Features/<Name>/` or `Views/` if it only composes feature code.
3. Reuse `DesignSystem` components — avoid one-off styling in feature files.
