import SwiftUI

// MARK: - Toolbar

struct AppToolbarRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColors.accent)
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(AppColors.accent)
            }
        }
        .disabled(isRefreshing)
        .accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")
    }
}

// MARK: - Buttons

/// Filled primary action — Sign in, Connect, Save.
struct AppPrimaryButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(minHeight: Layout.minTouchTarget)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var foregroundColor: Color {
        destructive ? Color(hex: 0xffe4e6) : Token.onPrimary
    }

    private var backgroundColor: Color {
        destructive ? Token.error : Token.primary
    }
}

/// Low-emphasis text action — Refresh status, Cancel links.
struct AppTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Bordered / subtle secondary action.
struct AppSecondaryButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(destructive ? AppColors.error : AppColors.label)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(minHeight: Layout.minTouchTarget)
            .background(AppColors.secondaryFill.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}

// MARK: - Chips

struct AppChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Token.onPrimary : Token.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: Layout.minTouchTarget)
                .background(isSelected ? Token.primary : Token.surfaceFillSecondary)
                .clipShape(Capsule())
                .overlay {
                    if isSelected {
                        Capsule()
                            .stroke(Token.primary.opacity(0.35), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Search field

struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isLoading = false
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(AppColors.secondaryLabel)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(AppColors.label)
                .onSubmit { onSubmit?() }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Layout.minTouchTarget)
        .background(AppColors.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - List rows

/// Compact EPS / surprise strip — reuses AppMetricStrip without repeating quarter chrome.
struct AppMetricPanel<Accessory: View>: View {
    let items: [(label: String, value: String)]
    @ViewBuilder var accessory: () -> Accessory

    init(
        items: [(label: String, value: String)],
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.items = items
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            accessory()
            AppMetricStrip(items: items)
        }
        .appPanel(subtle: true)
    }
}

struct AppListRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading()
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Feature checklist (plan cards, onboarding)

/// Compact checkmark list — keeps long feature copy behind disclosures readable.
struct AppFeatureChecklist: View {
    let items: [String]
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.top, 2)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - News headline row (Research news + earnings lists)

/// Compact headline row — title, metadata, optional external link.
struct AppNewsHeadlineRow: View {
    let item: NewsHeadline

    var body: some View {
        if let url = item.url.flatMap(URL.init(string:)) {
            Link(destination: url) {
                rowContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.headline)
                .font(AppTypography.bodySecondary.weight(.medium))
                .foregroundStyle(AppColors.label)
                .lineSpacing(3)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if !item.source.isEmpty {
                    Text(item.source)
                        .lineLimit(1)
                }
                if !item.source.isEmpty, !item.datetime.isEmpty {
                    Text("·")
                }
                if !item.datetime.isEmpty {
                    Text(DateFormatters.abbreviatedDay(from: item.datetime))
                }
                if item.url != nil {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryLabel)

            if item.url == nil, let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Inline banners

struct AppInlineBanner: View {
    enum Tone {
        case neutral, success, error

        var color: Color {
            switch self {
            case .neutral: AppColors.secondaryLabel
            case .success: AppColors.success
            case .error: AppColors.error
            }
        }
    }

    let message: String
    var tone: Tone = .neutral

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(tone.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tone.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Grouped list container (iOS inset grouped style)

struct AppGroupedList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}

struct AppGroupedDivider: View {
    var body: some View {
        Divider()
            .overlay(AppColors.separator)
            .padding(.leading, 16)
    }
}

// MARK: - Collapsible section (secondary content — signals, plan details, etc.)

struct AppDisclosureSection<Content: View>: View {
    let title: String
    var footnote: String?
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    AppScreenSectionLabel(title: title, footnote: footnote)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)

            if isExpanded {
                content()
                    .transition(.opacity)
            }
        }
        .clipped()
    }
}

// MARK: - Form field

struct AppFormField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(.body)
            .foregroundStyle(AppColors.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Layout.minTouchTarget, alignment: .leading)
            .background(AppColors.secondaryFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}

// MARK: - Status pill (beat / miss / plan badges)

struct AppStatusPill: View {
    let label: String
    var uppercase = true
    var tone: Tone = .neutral

    enum Tone {
        case neutral, success, error, warning

        var color: Color {
            switch self {
            case .neutral: AppColors.secondaryLabel
            case .success: AppColors.success
            case .error: AppColors.error
            case .warning: AppColors.warning
            }
        }
    }

    var body: some View {
        Text(uppercase ? label.uppercased() : label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Compact metric row (snapshot / quote strips)

struct AppMetricStrip: View {
    let items: [(label: String, value: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    Text(item.label)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.value)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(AppColors.separator)
                        .frame(width: 1, height: 32)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Symbol tag (alerts, search rows)

struct AppSymbolTag: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(AppTypography.captionEmphasis)
            .foregroundStyle(AppColors.accentHighlight)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColors.accent.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Empty / connect states

struct AppEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.accent)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button(actionTitle, action: action)
                .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(24)
        .appPanel(subtle: true)
    }
}

// MARK: - Inline empty / loading / error (tabs, lists)

/// Quiet empty copy — no large icon stack; keeps secondary tabs calm.
struct AppEmptyMessage: View {
    let message: String
    var systemImage = "tray"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(message)
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appPanel(subtle: true)
    }
}

/// Centered loading — shared by research depth tabs and bootstrap screens.
struct AppLoadingState: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.accent)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}

/// Retry block — banner + primary button instead of system borderedProminent.
struct AppErrorState: View {
    let message: String
    var retryTitle = "Try again"
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            AppInlineBanner(message: message, tone: .error)
            Button(retryTitle, action: retry)
                .buttonStyle(AppPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .appPanel(subtle: true)
    }
}

// MARK: - Auth screens (sign-in, waitlist)

/// Centered auth layout — brand mark, title, body, then actions.
struct AppAuthScreen<Actions: View>: View {
    var systemImage: String?
    var brandImageName: String?
    var iconColor: Color = AppColors.accent
    let title: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    init(
        systemImage: String? = nil,
        brandImageName: String? = nil,
        iconColor: Color = AppColors.accent,
        title: String,
        message: String,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.systemImage = systemImage
        self.brandImageName = brandImageName
        self.iconColor = iconColor
        self.title = title
        self.message = message
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                brandMark

                Text(title)
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            actions()

            Spacer(minLength: 0)
        }
        .padding(24)
        .appCenteredContentWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var brandMark: some View {
        if let brandImageName {
            Image(brandImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

/// Grouped primary action + footnote — used on sign-in.
struct AppAuthActionPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 14) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}
