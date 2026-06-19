import Foundation
import SQLite3

/// SQLite-backed history of `SystemSnapshot`s. Persists every sample to a local
/// database in Application Support, so history survives restarts and the
/// today/week ranges are meaningful.
///
/// Range queries are *downsampled* by time-bucketing in SQL (averaging within
/// each bucket) so a chart never has to plot more than a few hundred points,
/// regardless of how much raw history exists.
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

    /// Bumped on every recorded sample so SwiftUI views re-query and redraw.
    @Published private(set) var revision: Int = 0

    private var db: OpaquePointer?
    /// How many raw days to keep before pruning.
    private let retentionDays = 30

    init() {
        openDatabase()
        createSchema()
        prune()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: Writing

    func record(_ snapshot: SystemSnapshot) {
        guard let db else { return }
        let sql = """
        INSERT INTO snapshots
        (ts, cpu, mem_used, mem_total, battery, net_down, net_up, active_app, top_process)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, snapshot.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, snapshot.cpuUsage)
        sqlite3_bind_int64(stmt, 3, Int64(snapshot.memoryUsed))
        sqlite3_bind_int64(stmt, 4, Int64(snapshot.memoryTotal))
        if let battery = snapshot.batteryLevel {
            sqlite3_bind_double(stmt, 5, battery)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int64(stmt, 6, Int64(snapshot.networkDownBytesPerSec))
        sqlite3_bind_int64(stmt, 7, Int64(snapshot.networkUpBytesPerSec))
        bindText(stmt, 8, snapshot.activeAppBundleID)
        bindText(stmt, 9, snapshot.topProcessName)

        if sqlite3_step(stmt) == SQLITE_DONE {
            revision &+= 1
        }
    }

    // MARK: Reading

    /// Snapshots within `range`, time-bucketed (averaged) down to ~250 points.
    func snapshots(in range: Range) -> [SystemSnapshot] {
        guard let db else { return [] }
        let cutoff = startDate(for: range).timeIntervalSince1970
        let bucket = bucketSeconds(for: range)

        let sql = """
        SELECT MIN(ts), AVG(cpu), AVG(mem_used), AVG(mem_total),
               AVG(battery), AVG(net_down), AVG(net_up)
        FROM snapshots
        WHERE ts >= ?
        GROUP BY CAST(ts / ? AS INTEGER)
        ORDER BY ts;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_bind_double(stmt, 2, bucket)

        var result: [SystemSnapshot] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let battery: Double? = sqlite3_column_type(stmt, 4) == SQLITE_NULL
                ? nil : sqlite3_column_double(stmt, 4)
            result.append(
                SystemSnapshot(
                    timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                    cpuUsage: sqlite3_column_double(stmt, 1),
                    memoryUsed: UInt64(max(0, sqlite3_column_double(stmt, 2))),
                    memoryTotal: UInt64(max(0, sqlite3_column_double(stmt, 3))),
                    batteryLevel: battery,
                    networkDownBytesPerSec: UInt64(max(0, sqlite3_column_double(stmt, 5))),
                    networkUpBytesPerSec: UInt64(max(0, sqlite3_column_double(stmt, 6)))
                )
            )
        }
        return result
    }

    // MARK: Setup

    private func openDatabase() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flux", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let path = support.appendingPathComponent("flux.sqlite").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createSchema() {
        exec("""
        CREATE TABLE IF NOT EXISTS snapshots (
            ts REAL NOT NULL,
            cpu REAL NOT NULL,
            mem_used INTEGER NOT NULL,
            mem_total INTEGER NOT NULL,
            battery REAL,
            net_down INTEGER NOT NULL,
            net_up INTEGER NOT NULL,
            active_app TEXT,
            top_process TEXT
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_snapshots_ts ON snapshots(ts);")
    }

    private func prune() {
        let cutoff = Date.now.addingTimeInterval(-Double(retentionDays) * 86_400).timeIntervalSince1970
        exec("DELETE FROM snapshots WHERE ts < \(cutoff);")
    }

    // MARK: Helpers

    private func startDate(for range: Range) -> Date {
        let now = Date.now
        let calendar = Calendar.current
        switch range {
        case .fiveMinutes: return now.addingTimeInterval(-5 * 60)
        case .hour: return now.addingTimeInterval(-60 * 60)
        case .today: return calendar.startOfDay(for: now)
        case .week: return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }

    /// Bucket width that keeps each range around ~250 plotted points.
    private func bucketSeconds(for range: Range) -> Double {
        let span = Date.now.timeIntervalSince(startDate(for: range))
        return max(2, span / 250)
    }

    private func exec(_ sql: String) {
        guard let db else { return }
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
