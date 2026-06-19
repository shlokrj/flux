import Foundation
import Darwin

/// Enumerates running processes and their CPU / memory usage via the `libproc`
/// API (`proc_listpids` + `proc_pidinfo`).
///
/// Per-process CPU isn't reported directly — `proc_taskinfo` gives *cumulative*
/// CPU time, so usage is the delta in CPU time between two samples divided by
/// elapsed wall-clock time. The value is per-core and can exceed `1.0`. The
/// reader keeps the previous CPU times to compute that delta.
///
/// - Note: `proc_pidinfo` returns nothing for processes the current user can't
///   inspect (typically root-owned), so those are skipped. That's fine — the
///   heavy hitters are almost always the user's own apps.
struct ProcessReader {
    private var previousCPUTime: [pid_t: UInt64] = [:]
    private var previousSampleTime: Date?

    mutating func sample() -> [ProcessSnapshot] {
        let now = Date.now
        let elapsed = previousSampleTime.map { now.timeIntervalSince($0) } ?? 0
        defer { previousSampleTime = now }

        var current: [pid_t: UInt64] = [:]
        var snapshots: [ProcessSnapshot] = []

        for pid in Self.listPIDs() {
            guard let info = Self.taskInfo(for: pid) else { continue }

            let cpuTime = info.pti_total_user + info.pti_total_system
            current[pid] = cpuTime

            var usage = 0.0
            if elapsed > 0, let previous = previousCPUTime[pid], cpuTime >= previous {
                let deltaNanos = Double(cpuTime - previous)
                usage = deltaNanos / (elapsed * 1_000_000_000)
            }

            snapshots.append(
                ProcessSnapshot(
                    pid: pid,
                    name: Self.name(for: pid),
                    cpuUsage: usage,
                    memoryBytes: info.pti_resident_size,
                    startTime: Self.startTime(for: pid)
                )
            )
        }

        previousCPUTime = current
        return snapshots
    }

    // MARK: - libproc wrappers

    private static func listPIDs() -> [pid_t] {
        let maxBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard maxBytes > 0 else { return [] }

        let capacity = Int(maxBytes) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: capacity)
        let written = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, maxBytes)
        guard written > 0 else { return [] }

        let count = Int(written) / MemoryLayout<pid_t>.stride
        return pids.prefix(count).filter { $0 > 0 }
    }

    private static func taskInfo(for pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        return result == size ? info : nil
    }

    private static func startTime(for pid: pid_t) -> Date? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size, info.pbi_start_tvsec != 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
    }

    private static func name(for pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : "pid \(pid)"
    }
}
