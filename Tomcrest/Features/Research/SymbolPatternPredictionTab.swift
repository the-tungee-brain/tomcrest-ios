import SwiftUI

struct SymbolPatternPredictionContent: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        if account.hasProFeature(.patternTrend) {
            AppScreenSection(
                title: "5D Alpha",
                footnote: viewModel.patternPrediction?.display.isBenchmark == true
                    ? "Trend and regime indicators · Model C ranking not applicable"
                    : "Relative strength + trend ranking · next 5 sessions"
            ) {
                if let prediction = viewModel.patternPrediction {
                    PatternTrendForecastCard(forecast: prediction.display)
                } else {
                    AppEmptyMessage(
                        message: "Pattern forecast is not available for this symbol.",
                        systemImage: "waveform.path.ecg.rectangle"
                    )
                }
            }

            if let chartIntel = viewModel.patternIntelligence?.chartIntelligence, chartIntel.hasOverlays {
                AppScreenSection(
                    title: "Chart intelligence",
                    footnote: "Support, resistance, fib channel, and breakouts on a labeled 3M chart"
                ) {
                    NavigationLink {
                        ChartIntelligenceChartScreen(
                            symbol: viewModel.symbol,
                            intelligence: chartIntel
                        )
                    } label: {
                        ChartIntelligenceEntryCard(intelligence: chartIntel)
                    }
                    .buttonStyle(.plain)
                }
            }

            AppScreenSection(
                title: "Pattern intelligence",
                footnote: viewModel.patternIntelligence?.display.isBenchmark == true
                    ? "Pattern, trend, and regime context · no Model C on benchmark"
                    : "Confirms the core model — not a standalone trade signal"
            ) {
                if let intelligence = viewModel.patternIntelligence {
                    PatternIntelligenceCard(intelligence: intelligence.display)
                } else {
                    AppEmptyMessage(
                        message: "Pattern intelligence is not available for this symbol.",
                        systemImage: "sparkles"
                    )
                }
            }
        } else {
            AppScreenSection(
                title: "5D Alpha",
                footnote: "Pro feature"
            ) {
                AppInlineBanner(
                    message: "Upgrade to Pro for the 5-day alpha ranking forecast with pattern confirmation and relative strength signals.",
                    tone: .neutral
                )
            }
        }
    }
}

struct SymbolPatternPredictionTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .analysis, viewModel: viewModel) {
            SymbolPatternPredictionContent(viewModel: viewModel)
        }
    }
}
