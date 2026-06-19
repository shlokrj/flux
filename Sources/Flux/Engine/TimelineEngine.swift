import Foundation

/// Derives human-readable timeline events from the snapshot stream — the
/// feature that turns raw counters into a narrative
/// ("CPU spiked because Python started").
///
/// - Note: Phase 5. The detection rules below are stubs; the heuristics and
///   thresholds are sketched in `spec.md` §7. Events should be edge-triggered
///   and debounced so the timeline doesn't get spammed.
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

    @Published private(set) var events: [Event] = []

    /// Feed each new snapshot in; emit events on threshold transitions.
    ///
    /// TODO(phase5): evaluate the detection rules against `snapshot` (and recent
    /// history) and append events on the rising edge only.
    func ingest(_ snapshot: SystemSnapshot) {
        // placeholder — no detection yet.
    }
}
