import Foundation
import Darwin

/// Reads network throughput by diffing interface byte counters.
///
/// `getifaddrs` exposes cumulative in/out byte counts per interface
/// (`if_data`). Throughput is the delta between two samples divided by the
/// elapsed time. Loopback (`lo0`) is skipped. The first call has nothing to
/// diff against and reports 0.
struct NetworkReader {
    private var previous: (down: UInt64, up: UInt64, time: Date)?

    /// Bytes per second down and up since the last call.
    mutating func sample() -> (down: UInt64, up: UInt64) {
        let totals = Self.totals()
        let now = Date.now
        defer { previous = (totals.down, totals.up, now) }

        guard let prev = previous else { return (0, 0) }
        let elapsed = now.timeIntervalSince(prev.time)
        guard elapsed > 0 else { return (0, 0) }

        // Counters are cumulative and can wrap (32-bit); clamp negatives to 0.
        let down = totals.down >= prev.down ? totals.down - prev.down : 0
        let up = totals.up >= prev.up ? totals.up - prev.up : 0
        return (UInt64(Double(down) / elapsed), UInt64(Double(up) / elapsed))
    }

    /// Cumulative in/out bytes summed across all non-loopback interfaces.
    private static func totals() -> (down: UInt64, up: UInt64) {
        var down: UInt64 = 0
        var up: UInt64 = 0

        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return (0, 0) }
        defer { freeifaddrs(head) }

        var pointer = head
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            guard
                let addr = current.pointee.ifa_addr,
                Int32(addr.pointee.sa_family) == AF_LINK,
                let raw = current.pointee.ifa_data
            else { continue }

            if String(cString: current.pointee.ifa_name) == "lo0" { continue }

            let data = raw.assumingMemoryBound(to: if_data.self)
            down += UInt64(data.pointee.ifi_ibytes)
            up += UInt64(data.pointee.ifi_obytes)
        }

        return (down, up)
    }
}
