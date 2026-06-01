import SwiftUI

// MARK: - Motion (iOS-like springs)

private enum WatchlistFolderEditReorderMotion {
    static let lift = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let neighbor = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let finger = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.86)
}

/// Long-press card reorder for Watchlist edit mode.
@MainActor
@Observable
final class WatchlistFolderEditReorderController {
    private(set) var session: Session?
    private(set) var isDragging = false
    private(set) var rowHeight: CGFloat = 88

    var spacing: CGFloat = 12
    private var folders: [WatchlistFolder] = []
    var onCommit: ((_ from: Int, _ to: Int) -> Void)?

    struct Session: Equatable {
        let folderID: UUID
        let startIndex: Int
        var hoverIndex: Int
        var translation: CGFloat
        let rowStride: CGFloat
    }

    func configure(folders: [WatchlistFolder], spacing: CGFloat, onCommit: @escaping (_ from: Int, _ to: Int) -> Void) {
        self.folders = folders
        self.spacing = spacing
        self.onCommit = onCommit
    }

    func updateRowHeight(_ height: CGFloat) {
        guard height > 0, !isDragging else { return }
        rowHeight = height
    }

    func isActive(_ id: UUID) -> Bool {
        session?.folderID == id
    }

    var hasActiveSession: Bool {
        session != nil
    }

    func rowOffset(for index: Int) -> CGFloat {
        guard let session else { return 0 }
        let from = session.startIndex
        let to = session.hoverIndex
        let stride = session.rowStride

        if from < to, index > from, index <= to { return -stride }
        if from > to, index >= to, index < from { return stride }
        return 0
    }

    func begin(folder: WatchlistFolder, at index: Int) {
        if let session, session.folderID != folder.id {
            cancelReorder()
        }
        guard session == nil else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        let stride = rowHeight + spacing
        withAnimation(WatchlistFolderEditReorderMotion.lift) {
            session = Session(
                folderID: folder.id,
                startIndex: index,
                hoverIndex: index,
                translation: 0,
                rowStride: stride
            )
        }
    }

    func updateDrag(for folder: WatchlistFolder, translation: CGFloat) {
        guard session?.folderID == folder.id, var next = session else { return }

        isDragging = true
        let previousHover = next.hoverIndex
        next.translation = translation
        next.hoverIndex = hoverIndex(for: next)

        if next.hoverIndex != previousHover {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            withAnimation(WatchlistFolderEditReorderMotion.neighbor) {
                session = next
            }
        } else {
            session = next
        }
    }

    /// Commit or settle when the finger lifts.
    func completeReorder(for folder: WatchlistFolder) {
        guard let session, session.folderID == folder.id else { return }

        let from = session.startIndex
        let to = session.hoverIndex
        let commit = onCommit
        reset()

        guard from != to else { return }
        withAnimation(WatchlistFolderEditReorderMotion.settle) {
            commit?(from, to)
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
    }

    /// Drop lift without committing (finger up before drag, or recovery).
    func cancelReorder() {
        guard session != nil || isDragging else { return }
        reset()
    }

    private func reset() {
        withAnimation(WatchlistFolderEditReorderMotion.settle) {
            session = nil
        }
        isDragging = false
    }

    private func hoverIndex(for session: Session) -> Int {
        guard folders.count > 1 else { return session.startIndex }
        let steps = Int((session.translation / session.rowStride).rounded())
        return min(max(session.startIndex + steps, 0), folders.count - 1)
    }
}

private struct WatchlistFolderEditRowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 88

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct WatchlistFolderEditReorderSection<RowContent: View>: View {
    let title: String
    let folders: [WatchlistFolder]
    var spacing: CGFloat = 12
    @Bindable var controller: WatchlistFolderEditReorderController
    var onCommit: (_ from: Int, _ to: Int) -> Void
    @ViewBuilder var rowContent: (WatchlistFolder) -> RowContent

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                WatchlistFolderEditReorderRow(
                    folder: folder,
                    index: index,
                    controller: controller,
                    rowContent: rowContent(folder)
                )
            }
        }
        .onAppear {
            controller.configure(folders: folders, spacing: spacing, onCommit: onCommit)
        }
        .onChange(of: folders.map(\.id)) { _, _ in
            controller.configure(folders: folders, spacing: spacing, onCommit: onCommit)
            if controller.hasActiveSession {
                controller.cancelReorder()
            }
        }
        .onPreferenceChange(WatchlistFolderEditRowHeightKey.self) { height in
            controller.updateRowHeight(height)
        }
        .onDisappear {
            controller.cancelReorder()
        }
    }
}

private struct WatchlistFolderEditReorderRow<RowContent: View>: View {
    let folder: WatchlistFolder
    let index: Int
    @Bindable var controller: WatchlistFolderEditReorderController
    let rowContent: RowContent

    @GestureState private var isPointerDown = false

    var body: some View {
        let isActive = controller.isActive(folder.id)

        ZStack(alignment: .top) {
            if isActive, let session = controller.session {
                rowContent
                    .opacity(0.42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                AppColors.separator.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                            )
                    }
                    .animation(WatchlistFolderEditReorderMotion.lift, value: isActive)

                rowContent
                    .scaleEffect(1.05, anchor: .center)
                    .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                    .offset(y: session.translation - 10)
                    .animation(WatchlistFolderEditReorderMotion.finger, value: session.translation)
                    .zIndex(1)
            } else {
                rowContent
                    .background(rowHeightReader)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .gesture(reorderGesture)
        .onChange(of: isPointerDown) { _, down in
            guard !down else { return }
            guard controller.isActive(folder.id) else { return }
            if controller.isDragging {
                controller.completeReorder(for: folder)
            } else {
                controller.cancelReorder()
            }
        }
        .offset(y: isActive ? 0 : controller.rowOffset(for: index))
        .animation(WatchlistFolderEditReorderMotion.neighbor, value: controller.session?.hoverIndex)
        .zIndex(isActive ? 1 : 0)
        .accessibilityHint("Long press the folder, then drag to reorder.")
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28, maximumDistance: 24)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isPointerDown) { _, state, _ in
                state = true
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    controller.begin(folder: folder, at: index)
                case .second(true, let drag?):
                    controller.updateDrag(for: folder, translation: drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, _):
                    controller.completeReorder(for: folder)
                default:
                    controller.cancelReorder()
                }
            }
    }

    private var rowHeightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WatchlistFolderEditRowHeightKey.self, value: proxy.size.height)
        }
    }
}
