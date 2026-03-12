@preconcurrency import Darwin
import Foundation

/// Monitors system memory pressure (event-driven) and VM page statistics (polled).
final class MemoryMonitor {

    // MARK: - Types

    /// Current memory pressure level as reported by the kernel.
    enum PressureLevel: Equatable {
        case normal
        case warning
        case critical

        var isWarning: Bool {
            self == .warning || self == .critical
        }

        var displayName: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }
    }

    /// Snapshot of VM statistics for display purposes.
    struct Stats {
        let pressureLevel: PressureLevel
        let usedBytes: UInt64
        let totalBytes: UInt64

        var usedGB: Double { Double(usedBytes) / 1_073_741_824 }
        var totalGB: Double { Double(totalBytes) / 1_073_741_824 }

        var displayString: String {
            let usedStr = String(format: "%.1f GB", usedGB)
            let totalStr = String(format: "%.1f GB", totalGB)
            return "\(pressureLevel.displayName) (\(usedStr) / \(totalStr))"
        }

        static let unknown = Stats(
            pressureLevel: .normal,
            usedBytes: 0,
            totalBytes: 0
        )
    }

    // MARK: - Properties

    private var pressureSource: DispatchSourceMemoryPressure?
    private(set) var currentPressureLevel: PressureLevel = .normal
    private(set) var stats: Stats = .unknown

    /// Called on the main queue whenever memory state changes.
    var onChange: (() -> Void)?

    // MARK: - Lifecycle

    func start() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.handlePressureEvent(source: source)
        }
        source.resume()
        pressureSource = source

        // Capture initial state immediately.
        refreshStats()
    }

    func stop() {
        pressureSource?.cancel()
        pressureSource = nil
    }

    // MARK: - Polling

    /// Refresh VM page statistics (called on the 60-second timer tick).
    func refreshStats() {
        let pressure = readCurrentPressureLevel()
        let vmStats = readVMStats()

        currentPressureLevel = pressure
        stats = vmStats
    }

    // MARK: - Private

    private func handlePressureEvent(source: DispatchSourceMemoryPressure) {
        let event = source.data
        let newLevel: PressureLevel
        if event.contains(.critical) {
            newLevel = .critical
        } else if event.contains(.warning) {
            newLevel = .warning
        } else {
            newLevel = .normal
        }
        currentPressureLevel = newLevel
        refreshStats()
        onChange?()
    }

    private func readCurrentPressureLevel() -> PressureLevel {
        // Re-read from the current dispatch source data if available.
        // If no source is active, default to normal.
        guard let source = pressureSource else { return .normal }
        let event = source.data
        if event.contains(.critical) { return .critical }
        if event.contains(.warning) { return .warning }
        return .normal
    }

    private func readVMStats() -> Stats {
        var vmInfo = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return Stats(
                pressureLevel: currentPressureLevel,
                usedBytes: 0,
                totalBytes: ProcessInfo.processInfo.physicalMemory
            )
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let used = UInt64(
            vmInfo.active_count
                + vmInfo.wire_count
                + vmInfo.compressor_page_count
        ) * pageSize

        return Stats(
            pressureLevel: currentPressureLevel,
            usedBytes: used,
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }
}
