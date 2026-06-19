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
