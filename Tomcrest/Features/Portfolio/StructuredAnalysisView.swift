import SwiftUI

/// Renders structured AI analysis — overview, recommended action, and detail sections.
struct StructuredAnalysisView: View {
    let analysis: StructuredAnalysis
    var followUpSymbol: String?
    var onAskFollowUp: ((String) -> Void)?

    @State private var expandedSectionIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            overviewCard

            if let action = analysis.recommendedAction {
                recommendedActionCard(action)
            }

            if !analysis.sections.isEmpty {
                Text("More detail")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)

                ForEach(Array(analysis.sections.enumerated()), id: \.offset) { index, section in
                    sectionCard(section, index: index)
                }
            }
        }
        .onAppear {
            if expandedSectionIDs.isEmpty, let first = analysis.sections.first {
                expandedSectionIDs.insert(sectionKey(first, index: 0))
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overview")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            MarkdownText(content: analysis.summary, font: AppTypography.bodySecondary)
                .foregroundStyle(AppColors.label)
                .lineSpacing(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func recommendedActionCard(_ action: StructuredAnalysisAction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What I'd do next", systemImage: "sparkles")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)

            HStack(spacing: 6) {
                Text(action.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                if let symbol = action.symbol, !symbol.isEmpty {
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold).monospaced())
                        .foregroundStyle(AppColors.accentHighlight)
                }
            }

            MarkdownText(content: action.reason, font: .caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)

            if let onAskFollowUp, let followUpSymbol {
                Button("Ask follow-up in chat") {
                    onAskFollowUp(
                        "Follow up on my \(followUpSymbol.uppercased()) position analysis: \(action.title). \(action.reason)"
                    )
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentMuted.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionCard(_ section: StructuredAnalysisSection, index: Int) -> some View {
        let key = sectionKey(section, index: index)
        let isExpanded = expandedSectionIDs.contains(key)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedSectionIDs.remove(key)
                    } else {
                        expandedSectionIDs.insert(key)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let body = section.body, !body.isEmpty {
                        MarkdownText(content: body, font: .caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }

                    if let bullets = section.bullets {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(AppColors.accentHighlight)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    MarkdownText(content: bullet, font: .caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                        .lineSpacing(2)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(AppColors.secondaryBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private func sectionKey(_ section: StructuredAnalysisSection, index: Int) -> String {
        "\(index)-\(section.id)"
    }
}
