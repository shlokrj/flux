import Foundation

/// Persists `SystemSnapshot`s (and later app sessions + events) and serves the
/// range queries the dashboard needs.
///
/// - Note: Phase 3 will back this with SQLite (schema sketched in `spec.md` §9).
///   For now it's an in-memory ring of snapshots so the rest of the app can be
///   built against the real interface.
@MainActor
final class HistoryStore: ObservableObject {
    /// The time windows the dashboard can show.
    enum Range: String, CaseIterable, Identifiable {
        case fiveMinutes = "5m"
        case hour = "1h"
        case today = "Today"
        case week = "This week"

        var id: String { rawValue }
    }

    @Published private(set) var snapshots: [SystemSnapshot] = []

    /// Cap the in-memory buffer until SQLite lands.
    private let maxInMemory = 10_000

    func record(_ snapshot: SystemSnapshot) {
        snapshots.append(snapshot)
        if snapshots.count > maxInMemory {
            snapshots.removeFirst(snapshots.count - maxInMemory)
        }
    }

    /// Snapshots whose timestamp falls within `range`.
    func snapshots(in range: Range) -> [SystemSnapshot] {
        let cutoff = startDate(for: range)
        return snapshots.filter { $0.timestamp >= cutoff }
    }

    private func startDate(for range: Range) -> Date {
        let now = Date.now
        let calendar = Calendar.current
        switch range {
        case .fiveMinutes:
            return now.addingTimeInterval(-5 * 60)
        case .hour:
            return now.addingTimeInterval(-60 * 60)
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }
}
