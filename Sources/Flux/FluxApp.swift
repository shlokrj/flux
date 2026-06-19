import SwiftUI

/// Flux entry point.
///
/// Owns the long-lived collectors and the history store, and defines the two UI
/// surfaces: the always-present `MenuBarExtra` and the on-demand dashboard
/// `Window`.
@main
struct FluxApp: App {
    @StateObject private var metrics = MetricsCollector()
    @StateObject private var processes = ProcessCollector()
    @StateObject private var usage = AppUsageTracker()
    @StateObject private var history = HistoryStore()

    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(metrics: metrics, processes: processes)
        } label: {
            MenuBarLabel(metrics: metrics, history: history)
        }
        .menuBarExtraStyle(.window)

        Window("Flux Dashboard", id: "dashboard") {
            DashboardView(metrics: metrics, processes: processes, history: history)
        }
    }
}
