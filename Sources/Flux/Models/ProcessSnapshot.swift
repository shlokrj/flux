import Foundation

/// A single process as observed at one sampling tick.
///
/// These are produced per-tick by `ProcessCollector`. Only the top few (by CPU
/// and by memory) are persisted to history — keeping the full list around would
/// bloat the store.
struct ProcessSnapshot: Identifiable, Codable, Hashable {
    /// Process identifier; doubles as the stable id within a single tick.
    let id: Int32
    var pid: Int32 { id }

    let name: String
    /// CPU usage `0.0...1.0` per core — can exceed `1.0` across multiple cores.
    let cpuUsage: Double
    let memoryBytes: UInt64
    /// When the process was launched, if known.
    let startTime: Date?
    /// Bundle identifier, if the process maps to a known app.
    let bundleID: String?

    init(
        pid: Int32,
        name: String,
        cpuUsage: Double,
        memoryBytes: UInt64,
        startTime: Date? = nil,
        bundleID: String? = nil
    ) {
        self.id = pid
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryBytes = memoryBytes
        self.startTime = startTime
        self.bundleID = bundleID
    }
}

extension ProcessSnapshot {
    var cpuPercentText: String {
        "\(Int((cpuUsage * 100).rounded()))%"
    }

    /// e.g. `"1.4 GB"` or `"800 MB"`.
    var memoryText: String {
        let mb = Double(memoryBytes) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }
}
