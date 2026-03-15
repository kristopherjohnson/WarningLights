import Foundation
import IOKit.ps

/// Monitors battery charge level via IOKit power source APIs.
/// All mutable state is accessed on the main thread via run loop callbacks and explicit callers.
final class BatteryMonitor: @unchecked Sendable {

    // MARK: - Types

    struct Stats {
        let hasBattery: Bool
        let capacity: Int
        let isCharging: Bool

        /// Warning triggers only when on battery power and critically low.
        var isWarning: Bool {
            hasBattery && !isCharging && capacity < 20
        }

        var displayString: String {
            guard hasBattery else { return "" }
            return isCharging ? "\(capacity)% (charging)" : "\(capacity)%"
        }

        static let unknown = Stats(hasBattery: false, capacity: 0, isCharging: false)
    }

    // MARK: - Properties

    private(set) var stats: Stats = .unknown
    private var runLoopSource: CFRunLoopSource?

    /// Called on the main queue whenever power source state changes.
    var onChange: (() -> Void)?

    // MARK: - Lifecycle

    func start() {
        stats = readBatteryStats()

        // Use passUnretained because SystemMonitor holds BatteryMonitor for the app's lifetime.
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.handleChange()
            }
        }, context).takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    // MARK: - Polling

    func refresh() {
        stats = readBatteryStats()
    }

    // MARK: - Private

    private func handleChange() {
        stats = readBatteryStats()
        onChange?()
    }

    private func readBatteryStats() -> Stats {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unknown
        }
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as NSArray
        for element in list {
            let ps = element as AnyObject
            guard
                let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue()
                    as? [String: Any]
            else { continue }
            guard
                let type = desc[kIOPSTypeKey] as? String,
                type == kIOPSInternalBatteryType
            else { continue }
            let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let state = desc[kIOPSPowerSourceStateKey] as? String ?? kIOPSACPowerValue
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let normalizedCapacity =
                maxCapacity > 0 ? Int(Double(capacity) / Double(maxCapacity) * 100) : capacity
            return Stats(
                hasBattery: true,
                capacity: normalizedCapacity,
                isCharging: isCharging || state == kIOPSACPowerValue
            )
        }
        return .unknown
    }
}
