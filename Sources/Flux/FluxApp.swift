import SwiftUI
import AppKit

private final class FluxAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Flux entry point.
///
/// Owns the long-lived collectors and the history store, and defines the two UI
/// surfaces: the AppKit-backed status item and the dashboard window.
@main
struct FluxApp: App {
    @NSApplicationDelegateAdaptor(FluxAppDelegate.self) private var appDelegate
    @StateObject private var metrics = MetricsCollector()
    @StateObject private var processes = ProcessCollector()
    @StateObject private var usage = AppUsageTracker()
    @StateObject private var history = HistoryStore()
    @StateObject private var timeline = TimelineEngine()
    @StateObject private var devServers = DevServerCollector()
    @StateObject private var statusBar = StatusBarController()

    var body: some Scene {
        // WindowGroup guarantees a bootstrap window on launch. The status-bar
        // controller pins that first window, hides it on close, and removes any
        // duplicates; the New Window command below is also disabled.
        WindowGroup("Flux Dashboard", id: "dashboard") {
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
