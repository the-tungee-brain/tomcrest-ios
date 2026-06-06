import SwiftUI

struct SymbolPatternPredictionContent: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        if account.hasProFeature(.patternTrend) {
            AppScreenSection(
                title: "Relative Strength Evidence",
                footnote: viewModel.patternPrediction?.display.isBenchmark == true
                    ? "Quantitative model inputs · relative strength not applicable on benchmark"
                    : "Market-relative model evidence · next 5 sessions"
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
                    title: "Structure chart",
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

            if viewModel.patternIntelligence?.chartIntelligence?.hasAnalystSummary == true {
                AppScreenSection(
                    title: "Price Structure Evidence",
                    footnote: viewModel.patternIntelligence?.display.isBenchmark == true
                        ? "Qualitative 5-day read from structure and patterns"
                        : "Chart structure and pattern evidence"
                ) {
                    if let intelligence = viewModel.patternIntelligence {
                        PatternIntelligenceCard(intelligence: intelligence.display)
                    }
                }
            } else if viewModel.patternIntelligence != nil {
                AppScreenSection(title: "Price Structure Evidence") {
                    AppEmptyMessage(
                        message: "Chart structure summary is not available for this symbol.",
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
