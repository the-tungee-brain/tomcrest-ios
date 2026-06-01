import SwiftUI

struct SymbolPatternPredictionContent: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        AppScreenSection(
            title: "5D Trend",
            footnote: account.hasProFeature(.patternTrend)
                ? "Pattern model · next 5 sessions"
                : "Pro feature"
        ) {
            if account.hasProFeature(.patternTrend) {
                if let prediction = viewModel.patternPrediction {
                    PatternTrendForecastCard(forecast: prediction.display)
                } else {
                    AppEmptyMessage(
                        message: "Pattern forecast is not available for this symbol.",
                        systemImage: "waveform.path.ecg.rectangle"
                    )
                }
            } else {
                AppInlineBanner(
                    message: "Upgrade to Pro for the 5-day pattern trend forecast with probabilities and trade signal.",
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
