import Foundation
import Darwin

/// Reads physical memory usage from the Mach host.
///
/// Total RAM is fixed for the machine. "Used" approximates Activity Monitor's
/// *Memory Used* — app memory (internal pages minus purgeable) plus wired plus
/// compressed — from `host_statistics64(HOST_VM_INFO64)`.
struct MemoryReader {
    /// Total physical memory in bytes.
    let total: UInt64 = ProcessInfo.processInfo.physicalMemory

    /// Bytes currently in use.
    func usedBytes() -> UInt64 {
        guard let stats = Self.vmStats() else { return 0 }
        let pageSize = Self.pageSize()

        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)

        let appMemory = internalPages > purgeable ? internalPages - purgeable : 0
        return (appMemory + wired + compressed) * pageSize
    }

    private static func pageSize() -> UInt64 {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return UInt64(size)
    }

    private static func vmStats() -> vm_statistics64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        return result == KERN_SUCCESS ? stats : nil
    }
}
