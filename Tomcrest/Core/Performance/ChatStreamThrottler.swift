import Foundation

/// Coalesces high-frequency SSE chat chunks into periodic UI updates (~30fps).
@MainActor
final class ChatStreamThrottler {
    private var pending: [String: String] = [:]
    private var flushTask: Task<Void, Never>?
    private let flushInterval: Duration
    var apply: (String, String) -> Void

    init(flushInterval: Duration = .milliseconds(32), apply: @escaping (String, String) -> Void = { _, _ in }) {
        self.flushInterval = flushInterval
        self.apply = apply
    }

    func append(_ chunk: String, assistantId: String) {
        guard !chunk.isEmpty else { return }
        pending[assistantId, default: ""] += chunk
        scheduleFlush()
    }

    func flushAll() {
        flushTask?.cancel()
        flushTask = nil
        guard !pending.isEmpty else { return }
        let snapshot = pending
        pending.removeAll()
        for (assistantId, text) in snapshot where !text.isEmpty {
            apply(assistantId, text)
        }
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.flushInterval)
            guard !Task.isCancelled else { return }
            self.flushPending()
        }
    }

    private func flushPending() {
        flushTask = nil
        guard !pending.isEmpty else { return }
        let snapshot = pending
        pending.removeAll()
        for (assistantId, text) in snapshot where !text.isEmpty {
            apply(assistantId, text)
        }
    }
}
