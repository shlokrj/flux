import Foundation

/// Derives human-readable timeline events from the snapshot stream — the
/// feature that turns raw counters into a narrative
/// ("CPU spiked to 92%", "Battery dropped below 20%").
///
/// Detection is **edge-triggered**: an event fires on the transition into a
/// condition, not on every tick while it holds, so the timeline doesn't get
/// spammed. Thresholds are deliberately simple for now (see `spec.md` §7).
@MainActor
final class TimelineEngine: ObservableObject {
    struct Event: Identifiable, Hashable {
        enum Kind: String {
            case highCPU = "High CPU"
            case highMemory = "High memory"
            case lowBattery = "Low battery"
            case storageJump = "Storage jump"
            case networkSpike = "Network spike"
            case longRunningProcess = "Long-running process"
        }

        let id = UUID()
        let timestamp: Date
        let kind: Kind
        /// Human-readable description, e.g. "Chrome memory passed 2 GB".
        let message: String
    }

    /// Newest first.
    @Published private(set) var events: [Event] = []

    private let maxEvents = 200

    // Edge-detection state.
    private var cpuWasHigh = false
    private var memoryWasHigh = false
    private var networkWasSpiking = false
    private var lastBattery: Double?
    private var networkBaseline: Double = 0

    /// Feed each new snapshot in; emit events on threshold transitions.
    func ingest(_ snapshot: SystemSnapshot) {
        detectCPU(snapshot)
        detectMemory(snapshot)
        detectBattery(snapshot)
        detectNetwork(snapshot)
    }

    // MARK: Rules

    private func detectCPU(_ s: SystemSnapshot) {
        let high = s.cpuUsage >= 0.85
        defer { cpuWasHigh = high }
        guard high, !cpuWasHigh else { return }
        var message = "CPU spiked to \(s.cpuPercentText)"
        if let process = s.topProcessName { message += " — \(process)" }
        add(.highCPU, at: s.timestamp, message)
    }

    private func detectMemory(_ s: SystemSnapshot) {
        let high = s.memoryFraction >= 0.90
        defer { memoryWasHigh = high }
        guard high, !memoryWasHigh else { return }
        add(.highMemory, at: s.timestamp, "Memory usage passed 90% (\(s.memoryPercentText))")
    }

    private func detectBattery(_ s: SystemSnapshot) {
        guard let level = s.batteryLevel else { return }
        defer { lastBattery = level }
        guard let previous = lastBattery else { return }
        for threshold in [0.30, 0.20, 0.10] where previous > threshold && level <= threshold {
            add(.lowBattery, at: s.timestamp, "Battery dropped below \(Int(threshold * 100))%")
        }
    }

    private func detectNetwork(_ s: SystemSnapshot) {
        let down = Double(s.networkDownBytesPerSec)
        // Spike = well above the recent baseline, but at least 10 MB/s so quiet
        // periods don't generate noise.
        let threshold = max(networkBaseline * 5, 10 * 1_048_576)
        let spiking = down > threshold
        if spiking, !networkWasSpiking {
            let mbps = down / 1_048_576
            add(.networkSpike, at: s.timestamp, String(format: "Network spike — ↓ %.0f MB/s", mbps))
        }
        networkWasSpiking = spiking
        // Track a slow baseline of "normal" throughput (skip spikes).
        if !spiking {
            networkBaseline = networkBaseline == 0 ? down : networkBaseline * 0.9 + down * 0.1
        }
    }

    private func add(_ kind: Event.Kind, at timestamp: Date, _ message: String) {
        events.insert(Event(timestamp: timestamp, kind: kind, message: message), at: 0)
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }
}
