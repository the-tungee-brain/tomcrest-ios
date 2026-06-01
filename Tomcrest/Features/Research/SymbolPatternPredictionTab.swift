import SwiftUI

struct SymbolPatternPredictionTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .trend, viewModel: viewModel) {
            if let prediction = viewModel.patternPrediction {
                PatternTrendForecastCard(forecast: prediction.display)
            }
        }
    }
}
