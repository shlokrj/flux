import Foundation
import Combine

/// Samples system-wide metrics (CPU, memory, battery, network) on a timer and
/// publishes the most recent `SystemSnapshot`.
///
/// - Note: Phase 1 stub. `sample()` currently emits placeholder values; the real
///   reads (host_statistics64 / sysctl / IOKit / getifaddrs) are described in
///   `skills.md` and land next.
@MainActor
final class MetricsCollector: ObservableObject {
    /// The latest sampled snapshot, or `nil` before the first tick.
    @Published private(set) var latest: SystemSnapshot?

    private let interval: TimeInterval
    private var timer: Timer?

    private var cpu = CPUReader()
    private let memory = MemoryReader()
    private let battery = BatteryReader()
    private var network = NetworkReader()

    /// Where each sample is persisted / analyzed, if attached. Weak: both are
    /// owned by the app for its whole lifetime.
    private weak var history: HistoryStore?
    private weak var timeline: TimelineEngine?

    init(interval: TimeInterval = 2) {
        self.interval = interval
    }

    /// Begin sampling. Safe to call repeatedly — it restarts the timer. Pass a
    /// `HistoryStore` / `TimelineEngine` once (e.g. at launch) to start
    /// persisting and analyzing samples; later calls without them keep the same
    /// targets.
    func start(recording history: HistoryStore? = nil, timeline: TimelineEngine? = nil) {
        if let history { self.history = history }
        if let timeline { self.timeline = timeline }
        stop()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let net = network.sample()
        let snapshot = SystemSnapshot(
            cpuUsage: cpu.sample(),
            memoryUsed: memory.usedBytes(),
            memoryTotal: memory.total,
            batteryLevel: battery.level(),
            networkDownBytesPerSec: net.down,
            networkUpBytesPerSec: net.up
        )
        latest = snapshot
        history?.record(snapshot)
        timeline?.ingest(snapshot)
    }
}
