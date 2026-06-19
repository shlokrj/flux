import Foundation

/// A point-in-time capture of overall system resource usage.
///
/// This is the unit that gets persisted to the local history store every few
/// seconds, and the value the live UI renders.
struct SystemSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date

    /// Total CPU usage across all cores, `0.0...1.0`.
    let cpuUsage: Double
    /// Used / total physical memory, in bytes.
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    /// Battery charge `0.0...1.0`, or `nil` on machines without a battery.
    let batteryLevel: Double?
    /// Throughput since the previous snapshot, in bytes per second.
    let networkDownBytesPerSec: UInt64
    let networkUpBytesPerSec: UInt64
    /// Bundle identifier of the foreground app at capture time.
    let activeAppBundleID: String?
    /// Name of the top CPU-consuming process at capture time.
    let topProcessName: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        cpuUsage: Double,
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        batteryLevel: Double? = nil,
        networkDownBytesPerSec: UInt64 = 0,
        networkUpBytesPerSec: UInt64 = 0,
        activeAppBundleID: String? = nil,
        topProcessName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.batteryLevel = batteryLevel
        self.networkDownBytesPerSec = networkDownBytesPerSec
        self.networkUpBytesPerSec = networkUpBytesPerSec
        self.activeAppBundleID = activeAppBundleID
        self.topProcessName = topProcessName
    }
}

// MARK: - Display helpers
//
// Formatting lives on the model so the menu bar and dashboard don't duplicate it.
extension SystemSnapshot {
    /// Memory usage as a fraction, `0.0...1.0`.
    var memoryFraction: Double {
        memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal)
    }

    var cpuPercentText: String {
        "\(Int((cpuUsage * 100).rounded()))%"
    }

    var memoryPercentText: String {
        "\(Int((memoryFraction * 100).rounded()))%"
    }

    /// e.g. `"8.4 / 16.0 GB"`.
    var memoryText: String {
        let gb = 1_073_741_824.0
        return String(format: "%.1f / %.1f GB", Double(memoryUsed) / gb, Double(memoryTotal) / gb)
    }

    var batteryText: String {
        guard let batteryLevel else { return "—" }
        return "\(Int((batteryLevel * 100).rounded()))%"
    }

    /// e.g. `"↓ 12.0 MB/s  ↑ 1.4 MB/s"`.
    var networkText: String {
        func rate(_ bytes: UInt64) -> String {
            let mb = Double(bytes) / 1_048_576.0
            return String(format: "%.1f MB/s", mb)
        }
        return "↓ \(rate(networkDownBytesPerSec))  ↑ \(rate(networkUpBytesPerSec))"
    }
}
