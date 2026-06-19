import Foundation

/// Enumerates running processes and exposes them sorted by the active filter.
///
/// Sampling is on a timer via `start()`. Backed by `ProcessReader`.
///
/// - Note: enumeration runs on the main actor for now; if it ever shows up in
///   UI hitches, move the `ProcessReader.sample()` call off-main.
@MainActor
final class ProcessCollector: ObservableObject {
    /// How the process table is ordered.
    enum SortKey: String, CaseIterable, Identifiable {
        case cpu = "Highest CPU"
        case memory = "Highest memory"
        case longestRunning = "Longest running"
        case newest = "Newest"

        var id: String { rawValue }
    }

    @Published private(set) var processes: [ProcessSnapshot] = []
    @Published var sortKey: SortKey = .cpu

    private let interval: TimeInterval
    private var timer: Timer?
    private var reader = ProcessReader()

    init(interval: TimeInterval = 3) {
        self.interval = interval
    }

    /// Begin sampling. Safe to call repeatedly — it restarts the timer.
    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Take one sample of the live process list.
    func refresh() {
        processes = reader.sample()
    }

    /// The single highest-CPU process, regardless of the current sort.
    var topByCPU: ProcessSnapshot? {
        processes.max { $0.cpuUsage < $1.cpuUsage }
    }

    /// `processes` ordered by the current `sortKey`.
    var sorted: [ProcessSnapshot] {
        switch sortKey {
        case .cpu:
            return processes.sorted { $0.cpuUsage > $1.cpuUsage }
        case .memory:
            return processes.sorted { $0.memoryBytes > $1.memoryBytes }
        case .longestRunning:
            return processes.sorted { ($0.startTime ?? .now) < ($1.startTime ?? .now) }
        case .newest:
            return processes.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
        }
    }
}
