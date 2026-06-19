import Foundation

/// A continuous stretch of time during which a single app was frontmost.
///
/// Produced by `AppUsageTracker` from `NSWorkspace` activation events. A session
/// with `end == nil` is the one currently in progress.
struct AppUsageSession: Identifiable, Codable, Hashable {
    let id: UUID
    let bundleID: String
    let appName: String
    let start: Date
    /// `nil` while this session is still active.
    var end: Date?

    init(
        id: UUID = UUID(),
        bundleID: String,
        appName: String,
        start: Date = .now,
        end: Date? = nil
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.start = start
        self.end = end
    }

    var isActive: Bool { end == nil }

    /// Elapsed time, measured to `end` (or now, if still active).
    var duration: TimeInterval {
        (end ?? .now).timeIntervalSince(start)
    }
}

extension AppUsageSession {
    /// e.g. `"3h 42m"`, `"58m"`, `"45s"`.
    var durationText: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }
}
