import Darwin

/// Reads system-wide CPU usage from the Mach host.
///
/// `host_statistics(HOST_CPU_LOAD_INFO)` returns *cumulative* tick counts since
/// boot (user / system / idle / nice), so usage is the ratio of busy-to-total
/// ticks **between two samples**. The reader keeps the previous reading; the
/// first call has nothing to diff against and reports 0.
struct CPUReader {
    private var previous: host_cpu_load_info?

    /// Fraction of CPU time spent busy since the last call, `0.0...1.0`.
    mutating func sample() -> Double {
        guard let current = Self.load() else { return 0 }
        defer { previous = current }
        guard let previous else { return 0 }

        // cpu_ticks is [user, system, idle, nice]. Diff in Double to avoid any
        // unsigned underflow if a counter is ever observed out of order.
        let user = Double(current.cpu_ticks.0) - Double(previous.cpu_ticks.0)
        let system = Double(current.cpu_ticks.1) - Double(previous.cpu_ticks.1)
        let idle = Double(current.cpu_ticks.2) - Double(previous.cpu_ticks.2)
        let nice = Double(current.cpu_ticks.3) - Double(previous.cpu_ticks.3)

        let busy = user + system + nice
        let total = busy + idle
        guard total > 0 else { return 0 }
        return max(0, min(1, busy / total))
    }

    private static func load() -> host_cpu_load_info? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info : nil
    }
}
