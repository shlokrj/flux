import Foundation

/// Polls for local listening ports (dev servers) on a timer. Backed by
/// `PortScanner`. The scan shells out to `lsof`, so it runs off the main actor
/// and publishes results back on it.
///
/// Only needed while the dashboard is visible, so it's started/stopped by the
/// dashboard rather than at launch.
@MainActor
final class DevServerCollector: ObservableObject {
    @Published private(set) var servers: [DevServer] = []

    private let interval: TimeInterval
    private var timer: Timer?

    init(interval: TimeInterval = 5) {
        self.interval = interval
    }

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

    func refresh() {
        // Inherit the main actor here; run only the blocking scan off-main.
        Task {
            let servers = await Task.detached(priority: .utility) {
                PortScanner.listeningServers()
            }.value
            self.servers = servers
        }
    }
}
