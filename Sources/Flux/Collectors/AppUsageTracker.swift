import Foundation
import AppKit

/// Tracks which application is frontmost over time and records
/// `AppUsageSession`s.
///
/// Backed by `NSWorkspace` activation notifications — event-driven, so no
/// polling. This is the foundation of the Screen-Time-style usage analytics.
///
/// - Note: Idle/sleep handling (pausing a session when the machine is idle or
///   asleep) is not implemented yet — see `spec.md` §6 / `skills.md`.
/// One app's aggregated foreground time over some window.
struct AppUsage: Identifiable, Hashable {
    let id: String  // bundle identifier
    let appName: String
    let duration: TimeInterval

    /// e.g. `"3h 42m"`, `"58m"`, `"45s"`.
    var durationText: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }
}

@MainActor
final class AppUsageTracker: ObservableObject {
    /// The session currently in progress, if any.
    @Published private(set) var current: AppUsageSession?

    private var observer: NSObjectProtocol?
    /// Completed sessions are persisted here; aggregation lives in the store.
    private weak var history: HistoryStore?

    /// Begin observing frontmost-app changes, persisting completed sessions to
    /// `history` if provided.
    func start(recording history: HistoryStore? = nil) {
        if let history { self.history = history }
        guard observer == nil else { return }

        // Seed with whatever is frontmost right now.
        if let app = NSWorkspace.shared.frontmostApplication {
            switchTo(app)
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard
                    let self,
                    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }
                self.switchTo(app)
            }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    /// Close out the current session and open a new one for `app`.
    private func switchTo(_ app: NSRunningApplication) {
        let now = Date.now

        if var ongoing = current {
            // Ignore re-activation of the same app.
            if ongoing.bundleID == (app.bundleIdentifier ?? "unknown") { return }
            ongoing.end = now
            history?.recordSession(ongoing)
        }

        current = AppUsageSession(
            bundleID: app.bundleIdentifier ?? "unknown",
            appName: app.localizedName ?? "Unknown",
            start: now
        )
    }
}
