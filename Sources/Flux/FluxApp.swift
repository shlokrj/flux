import SwiftUI

/// Flux entry point.
///
/// Owns the long-lived collectors and the history store, and defines the two UI
/// surfaces: the AppKit-backed status item and the dashboard window.
@main
struct FluxApp: App {
    @StateObject private var metrics = MetricsCollector()
    @StateObject private var processes = ProcessCollector()
    @StateObject private var usage = AppUsageTracker()
    @StateObject private var history = HistoryStore()
    @StateObject private var timeline = TimelineEngine()
    @StateObject private var devServers = DevServerCollector()
    @StateObject private var statusBar = StatusBarController()

    var body: some Scene {
        // `Window` is unique by design: Flux should never create multiple
        // dashboards when the status item is clicked repeatedly.
        Window("Flux Dashboard", id: "dashboard") {
            DashboardView(metrics: metrics, processes: processes, history: history, usage: usage, timeline: timeline, devServers: devServers)
                .task {
                    statusBar.configure(
                        metrics: metrics,
                        processes: processes,
                        history: history,
                        usage: usage,
                        timeline: timeline
                    )
                }
        }
        .commands {
            // Flux has one dashboard; do not expose a New Window command.
            CommandGroup(replacing: .newItem) { }
        }
    }
}
