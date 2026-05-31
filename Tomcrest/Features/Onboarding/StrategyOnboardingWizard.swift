import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case strategy
    case preferences
    case configure
    case review
}

struct StrategyOnboardingWizard: View {
    @Environment(\.dismiss) private var dismiss
    let catalog: [StrategyCatalogItem]
    var onComplete: (UserInvestmentProfileUpdate) async -> Void
    var onSaveDraft: ((UserInvestmentProfileUpdate) async -> Void)?

    @State private var step: OnboardingStep = .welcome
    @State private var selectedStrategyId: String?
    @State private var riskTolerance = "moderate"
    @State private var optionsExperience = "beginner"
    @State private var incomeVsGrowth = "balanced"
    @State private var watchlistText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    progressHeader

                    switch step {
                    case .welcome:
                        welcomeStep
                    case .strategy:
                        strategyStep
                    case .preferences:
                        preferencesStep
                    case .configure:
                        configureStep
                    case .review:
                        reviewStep
                    }

                    if let errorMessage {
                        AppInlineBanner(message: errorMessage, tone: .error)
                    }

                    navigationButtons
                }
            }
            .appRootNavigation("Strategy setup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            ProgressView(value: Double(step.rawValue + 1), total: Double(OnboardingStep.allCases.count))
                .tint(AppColors.accent)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to your strategy playbook")
                .font(AppTypography.sectionTitle)
            Text("Pick an investing style, set preferences, and add symbols. Tomcrest will guide your next actions on Portfolio Today.")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
        }
        .appPanel(subtle: true)
    }

    private var strategyStep: some View {
        AppScreenSection(title: "Choose a strategy") {
            VStack(spacing: 10) {
                ForEach(catalog) { item in
                    Button {
                        selectedStrategyId = item.id
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.label)
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            selectedStrategyId == item.id
                                ? AppColors.accentMuted.opacity(0.45)
                                : AppColors.secondaryBackground.opacity(0.55)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    selectedStrategyId == item.id ? AppColors.accent : AppColors.separator,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            preferencePicker("Risk tolerance", selection: $riskTolerance, options: StrategyFormSupport.riskOptions)
            preferencePicker(
                "Options experience",
                selection: $optionsExperience,
                options: ["beginner", "intermediate", "advanced"]
            )
            preferencePicker(
                "Income vs growth",
                selection: $incomeVsGrowth,
                options: ["income", "balanced", "growth"]
            )
        }
        .appPanel(subtle: true)
    }

    private var configureStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add symbols")
                .font(AppTypography.sectionTitle)
            Text("Enter tickers for your playbook (comma or space separated). Use the screener in Settings anytime.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            TextField("AAPL MSFT SCHD", text: $watchlistText, axis: .vertical)
                .lineLimit(3 ... 6)
                .textInputAutocapitalization(.characters)
                .font(.body.monospaced())
                .padding(12)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .appPanel(subtle: true)
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            reviewRow("Strategy", selectedStrategyId ?? "—")
            reviewRow("Risk", riskTolerance.capitalized)
            reviewRow("Symbols", watchlistText.isEmpty ? "None yet" : watchlistText)
        }
        .appPanel(subtle: true)
    }

    private var navigationButtons: some View {
        HStack {
            if step != .welcome {
                Button("Back") { step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
            }
            Spacer()
            Button(primaryButtonTitle) {
                Task { await advance() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(canAdvance ? AppColors.accent : AppColors.secondaryFill)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(!canAdvance || isSaving)
        }
    }

    private var primaryButtonTitle: String {
        step == .review ? (isSaving ? "Saving…" : "Finish") : "Continue"
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome: true
        case .strategy: selectedStrategyId != nil
        case .preferences, .configure: true
        case .review: selectedStrategyId != nil
        }
    }

    private func advance() async {
        errorMessage = nil
        if step != .review {
            if step == .configure, let onSaveDraft {
                isSaving = true
                await onSaveDraft(buildUpdate(complete: false))
                isSaving = false
            }
            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .review
            return
        }

        isSaving = true
        await onComplete(buildUpdate(complete: true))
        isSaving = false
        dismiss()
    }

    private func buildUpdate(complete: Bool) -> UserInvestmentProfileUpdate {
        var update = StrategyFormSupport.buildUpdate(
            strategyId: selectedStrategyId ?? "wheel",
            riskTolerance: riskTolerance,
            symbols: StrategyFormSupport.parseSymbols(watchlistText),
            profile: nil
        )
        if complete {
            return UserInvestmentProfileUpdate(
                primaryStrategy: update.primaryStrategy,
                riskTolerance: update.riskTolerance,
                optionsExperience: optionsExperience,
                incomeVsGrowth: incomeVsGrowth,
                wheel: update.wheel,
                dividend: update.dividend,
                etfCore: update.etfCore,
                completeOnboarding: true
            )
        }
        return update
    }

    private func preferencePicker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsFieldLabel(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        AppChip(title: option.capitalized, isSelected: selection.wrappedValue == option) {
                            selection.wrappedValue = option
                        }
                    }
                }
            }
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
    }
}
