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

    init(interval: TimeInterval = 2) {
        self.interval = interval
    }

    /// Begin sampling. Safe to call repeatedly — it restarts the timer.
    func start() {
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
        latest = SystemSnapshot(
            cpuUsage: cpu.sample(),
            memoryUsed: memory.usedBytes(),
            memoryTotal: memory.total,
            batteryLevel: battery.level(),
            networkDownBytesPerSec: net.down,
            networkUpBytesPerSec: net.up
        )
    }
}
