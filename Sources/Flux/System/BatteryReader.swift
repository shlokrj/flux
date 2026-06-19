import Foundation
import IOKit.ps

/// Reads battery charge from IOKit's power-sources API.
///
/// Walks the power sources and returns the first one that reports a capacity.
/// Desktops (and anything without a battery) report no sources, so `level()`
/// returns `nil`.
struct BatteryReader {
    /// Charge as a fraction `0.0...1.0`, or `nil` if there's no battery.
    func level() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as? [String: Any],
                let current = description[kIOPSCurrentCapacityKey as String] as? Int,
                let maximum = description[kIOPSMaxCapacityKey as String] as? Int,
                maximum > 0
            else { continue }

            return Double(current) / Double(maximum)
        }

        return nil
    }
}
