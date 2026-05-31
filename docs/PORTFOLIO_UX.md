# Portfolio UX redesign

## Main dashboard (at a glance)

Stays on the Portfolio tab scroll:

| Element | Purpose |
|---------|---------|
| **Hero summary** | Total value, today P/L, open P/L (+ %), cash, last sync |
| **Strategy nudge** | Only when onboarding incomplete (dismissible) |
| **Morning brief preview** | Two-line teaser → opens **Today** |
| **Explore links** | Today, Holdings & risk, Headlines, Activity |
| **Top holdings** | Up to 6 symbols (weight, value, today P/L) → tap opens Research |

Removed from main screen: segmented Today / News / Holdings / Activity tabs, full morning brief, attention list, playbook card, AI analysis, chat panel, holdings sort/filter, options risk cards.

## Secondary screens (NavigationStack push)

| Screen | Former location | Contents |
|--------|-----------------|----------|
| **Today** | “Today” tab | Onboarding, full brief, attention, playbook, portfolio analysis, chat |
| **Holdings** | “Holdings” tab | CSP/assignment risk, full sortable holdings table |
| **Headlines** | “News” tab | Portfolio news list |
| **Activity** | “Activity” tab | Recent orders with filters |

## Why

- **Cognitive load**: The old screen stacked 4 tab modes plus dense cards; most users need value, P/L, and top positions first.
- **Progressive disclosure**: Briefing, analytics, and chat are valuable but not “glance” content — they live one tap away.
- **Visual calm**: Single hero block, grouped explore rows, compact holdings — fewer nested disclosures on first paint.

## Files

```
Features/Portfolio/
├── Navigation/PortfolioDestination.swift
├── Dashboard/PortfolioDashboardComponents.swift
├── Screens/PortfolioDetailScreens.swift
├── PortfolioView.swift              ← dashboard only
└── PortfolioViewModel.swift       ← +totalDayProfitLoss, topHoldings()
```

Legacy `PortfolioSectionTabBar` and `PortfolioSnapshotCard` remain for reuse elsewhere but are no longer used on the main Portfolio route.
