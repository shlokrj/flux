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
    /// Completed sessions, oldest first.
    @Published private(set) var sessions: [AppUsageSession] = []

    private var observer: NSObjectProtocol?

    /// Begin observing frontmost-app changes.
    func start() {
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

    /// Total foreground time per app, longest first — clipped to today.
    func usageToday() -> [AppUsage] {
        let dayStart = Calendar.current.startOfDay(for: .now)
        var totals: [String: (name: String, duration: TimeInterval)] = [:]

        var all = sessions
        if let current { all.append(current) }

        for session in all {
            let start = max(session.start, dayStart)
            let end = session.end ?? .now
            guard end > start else { continue }
            var entry = totals[session.bundleID] ?? (session.appName, 0)
            entry.duration += end.timeIntervalSince(start)
            entry.name = session.appName
            totals[session.bundleID] = entry
        }

        return totals
            .map { AppUsage(id: $0.key, appName: $0.value.name, duration: $0.value.duration) }
            .sorted { $0.duration > $1.duration }
    }

    /// Close out the current session and open a new one for `app`.
    private func switchTo(_ app: NSRunningApplication) {
        let now = Date.now

        if var ongoing = current {
            // Ignore re-activation of the same app.
            if ongoing.bundleID == (app.bundleIdentifier ?? "unknown") { return }
            ongoing.end = now
            sessions.append(ongoing)
        }

        current = AppUsageSession(
            bundleID: app.bundleIdentifier ?? "unknown",
            appName: app.localizedName ?? "Unknown",
            start: now
        )
    }
}
