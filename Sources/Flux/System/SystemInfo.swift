import Foundation
import Darwin

/// Slow-moving system facts that don't need the per-tick snapshot treatment:
/// boot uptime and disk capacity. Read on demand.
enum SystemInfo {
    // MARK: Uptime

    /// Wall-clock time since boot. Uses `KERN_BOOTTIME` rather than
    /// `ProcessInfo.systemUptime`, which excludes time spent asleep.
    static var uptime: TimeInterval {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        let result = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0)
        guard result == 0, bootTime.tv_sec != 0 else {
            return ProcessInfo.processInfo.systemUptime
        }
        let boot = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
        return max(0, Date().timeIntervalSince(boot))
    }

    /// e.g. `"3d 4h"`, `"4h 12m"`, `"12m"`.
    static var uptimeText: String {
        let total = Int(uptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: Disk

    /// Free / total bytes for the root volume, or `nil` if it can't be read.
    static func disk() -> (free: UInt64, total: UInt64)? {
        let url = URL(fileURLWithPath: "/")
        guard
            let values = try? url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey,
            ]),
            let total = values.volumeTotalCapacity, total > 0
        else { return nil }

        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        return (UInt64(max(0, free)), UInt64(total))
    }

    /// e.g. `"312 / 994 GB"` (used / total).
    static var diskText: String {
        guard let disk = disk() else { return "—" }
        let gb = 1_073_741_824.0
        let used = disk.total > disk.free ? disk.total - disk.free : 0
        return String(format: "%.0f / %.0f GB", Double(used) / gb, Double(disk.total) / gb)
    }
}
