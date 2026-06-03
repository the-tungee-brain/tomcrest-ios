import SwiftUI

struct SymbolPatternPredictionContent: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        if account.hasProFeature(.patternTrend) {
            AppScreenSection(
                title: "Trend analysis",
                footnote: viewModel.patternPrediction?.display.isBenchmark == true
                    ? "Quantitative model inputs · ranking not applicable on benchmark"
                    : "Quantitative model outputs · next 5 sessions"
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
                    title: "Chart intelligence",
                    footnote: viewModel.patternIntelligence?.display.isBenchmark == true
                        ? "Qualitative 5-day read from structure and patterns"
                        : "What to expect — see Trend analysis for model scores"
                ) {
                    if let intelligence = viewModel.patternIntelligence {
                        PatternIntelligenceCard(intelligence: intelligence.display)
                    }
                }
            } else if viewModel.patternIntelligence != nil {
                AppScreenSection(title: "Chart intelligence") {
                    AppEmptyMessage(
                        message: "Analyst summary is not available for this symbol.",
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
