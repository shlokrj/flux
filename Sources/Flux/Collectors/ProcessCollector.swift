import Foundation

/// Enumerates running processes and exposes them sorted by the active filter.
///
/// - Note: Phase 1 stub. `refresh()` is a no-op until process enumeration
///   (proc_listpids / proc_pid_rusage / proc_pidinfo) is wired up — see
///   `skills.md`.
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

    /// TODO(phase1): enumerate live processes and populate `processes`.
    func refresh() {
        // placeholder — no live processes yet.
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
