import SwiftUI

enum WheelPhaseSteps {
    static func steps(for strategyId: String) -> [(id: String, label: String)] {
        if StrategyPlaybookHelpers.isWheelLikeStrategy(strategyId) {
            return [
                ("pick-symbol", "Pick"),
                ("ready-for-csp", "Ready"),
                ("short-put-open", "Put"),
                ("assigned-shares", "Own"),
                ("short-call-open", "Call"),
                ("complete-cycle", "Done"),
            ]
        }
        return []
    }

    static func activeIndex(phase: String?, steps: [(id: String, label: String)]) -> Int {
        guard let phase else { return 0 }
        return steps.firstIndex(where: { $0.id == phase }) ?? 0
    }
}

struct StrategyWheelPhaseStepper: View {
    let strategyId: String
    let phase: String?

    private var steps: [(id: String, label: String)] {
        WheelPhaseSteps.steps(for: strategyId)
    }

    private var activeIndex: Int {
        WheelPhaseSteps.activeIndex(phase: phase, steps: steps)
    }

    var body: some View {
        if steps.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 0) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(fillColor(for: index))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if index < activeIndex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(AppColors.onAccent)
                                        } else {
                                            Text("\(index + 1)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(index == activeIndex ? AppColors.onAccent : AppColors.secondaryLabel)
                                        }
                                    }
                                Text(step.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(index <= activeIndex ? AppColors.label : AppColors.tertiaryLabel)
                            }

                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(index < activeIndex ? AppColors.accent : AppColors.separator)
                                    .frame(width: 18, height: 2)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func fillColor(for index: Int) -> Color {
        if index < activeIndex { return AppColors.accent }
        if index == activeIndex { return AppColors.accentHighlight }
        return AppColors.secondaryFill
    }
}

struct StrategySerpentineFlowDiagram: View {
    let flow: StrategyFlowDefinition

    private var rows: [SerpentineFlowRow] {
        SerpentineFlowLayout.buildRows(from: flow.nodes)
    }

    private var showLoop: Bool {
        flow.repeats && SerpentineFlowLayout.hasLeftColumnLoop(flow.nodes)
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                rowView(row)

                if rowIndex < rows.count - 1 {
                    verticalConnector(
                        from: row,
                        to: rows[rowIndex + 1],
                        isLoopRow: showLoop && rowIndex == 0
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func rowView(_ row: SerpentineFlowRow) -> some View {
        switch row {
        case let .pair(direction, first, second):
            if direction == .leftToRight {
                serpentineThreeColumnRow(
                    left: { flowNodeCard(first.node, index: first.index) },
                    center: { horizontalArrow(.right) },
                    right: { flowNodeCard(second.node, index: second.index) }
                )
            } else {
                serpentineThreeColumnRow(
                    left: { flowNodeCard(second.node, index: second.index) },
                    center: { horizontalArrow(.left) },
                    right: { flowNodeCard(first.node, index: first.index) }
                )
            }
        case let .single(node, index):
            HStack(spacing: SerpentineFlowLayout.columnSpacing) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                flowNodeCard(node, index: index)
                    .frame(maxWidth: SerpentineFlowLayout.singleNodeMaxWidth)
                Color.clear
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    private func serpentineThreeColumnRow<Left: View, Center: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(alignment: .center, spacing: SerpentineFlowLayout.columnSpacing) {
            left()
                .frame(maxWidth: .infinity, alignment: .center)
            center()
                .frame(width: SerpentineFlowLayout.arrowLaneWidth, alignment: .center)
            right()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func verticalConnector(
        from current: SerpentineFlowRow,
        to next: SerpentineFlowRow,
        isLoopRow: Bool
    ) -> some View {
        if isLoopRow {
            serpentineThreeColumnRow(
                left: { verticalArrow(.up) },
                center: {
                    Color.clear
                        .accessibilityHidden(true)
                },
                right: { verticalArrow(.down) }
            )
            .frame(height: SerpentineFlowLayout.verticalConnectorHeight)
        } else {
            let column = SerpentineFlowLayout.downArrowColumn(from: current, to: next)
            serpentineThreeColumnRow(
                left: { connectorSlot(showArrow: column == .left, direction: .down) },
                center: { connectorSlot(showArrow: column == .center, direction: .down) },
                right: { connectorSlot(showArrow: column == .right, direction: .down) }
            )
            .frame(height: SerpentineFlowLayout.verticalConnectorHeight)
        }
    }

    @ViewBuilder
    private func connectorSlot(showArrow: Bool, direction: VerticalArrowDirection) -> some View {
        Group {
            if showArrow {
                verticalArrow(direction)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
    }

    private func flowNodeCard(_ node: StrategyFlowNode, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 20, height: 20)
                .background(AppColors.accentMuted.opacity(0.5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(node.caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SerpentineFlowLayout.cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: SerpentineFlowLayout.cardHeight,
            maxHeight: SerpentineFlowLayout.cardHeight,
            alignment: .topLeading
        )
        .background(AppColors.background.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.separator.opacity(0.8), lineWidth: 1)
        }
    }

    private func horizontalArrow(_ direction: HorizontalArrowDirection) -> some View {
        Image(systemName: direction == .right ? "arrow.right" : "arrow.left")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.tertiaryLabel)
            .frame(width: SerpentineFlowLayout.arrowLaneWidth, height: SerpentineFlowLayout.arrowLaneWidth)
    }

    private func verticalArrow(_ direction: VerticalArrowDirection) -> some View {
        Image(systemName: direction == .down ? "arrow.down" : "arrow.up")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.tertiaryLabel)
            .frame(width: SerpentineFlowLayout.arrowLaneWidth, height: SerpentineFlowLayout.arrowLaneWidth)
    }
}

private enum HorizontalArrowDirection {
    case left
    case right
}

private enum VerticalArrowDirection {
    case up
    case down
}

private enum SerpentineDirection {
    case leftToRight
    case rightToLeft
}

private enum SerpentineFlowRow {
    case pair(
        direction: SerpentineDirection,
        first: (node: StrategyFlowNode, index: Int),
        second: (node: StrategyFlowNode, index: Int)
    )
    case single(node: StrategyFlowNode, index: Int)
}

private enum VerticalArrowColumn {
    case left
    case center
    case right
}

private enum SerpentineFlowLayout {
    static let cardHeight: CGFloat = 84
    static let cardPadding: CGFloat = 10
    static let columnSpacing: CGFloat = 8
    static let arrowLaneWidth: CGFloat = 24
    static let verticalConnectorHeight: CGFloat = 28
    static let singleNodeMaxWidth: CGFloat = 240

    static func buildRows(from nodes: [StrategyFlowNode]) -> [SerpentineFlowRow] {
        var rows: [SerpentineFlowRow] = []
        var index = 0
        var rowNumber = 0

        while index < nodes.count {
            let remaining = nodes.count - index
            if remaining == 1 {
                rows.append(.single(node: nodes[index], index: index))
                break
            }

            let direction: SerpentineDirection = rowNumber.isMultiple(of: 2) ? .leftToRight : .rightToLeft
            rows.append(
                .pair(
                    direction: direction,
                    first: (nodes[index], index),
                    second: (nodes[index + 1], index + 1)
                )
            )
            index += 2
            rowNumber += 1
        }

        return rows
    }

    static func hasLeftColumnLoop(_ nodes: [StrategyFlowNode]) -> Bool {
        nodes.count >= 2 && nodes.count.isMultiple(of: 2)
    }

    static func downArrowColumn(from current: SerpentineFlowRow, to next: SerpentineFlowRow) -> VerticalArrowColumn {
        guard case let .pair(direction, _, _) = current else {
            return .center
        }

        if direction == .leftToRight {
            return .right
        }

        if case .single = next {
            return .center
        }

        return .left
    }
}
