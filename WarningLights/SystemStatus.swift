import Foundation
import SwiftUI

/// Aggregated snapshot of all monitored system metrics.
struct SystemStatus {
    let memory: MemoryMonitor.Stats
    let disk: DiskMonitor.Stats
    let cpu: CPUMonitor.Stats
    let battery: BatteryMonitor.Stats

    /// True when any metric is in a warning state.
    var hasWarning: Bool {
        memory.pressureLevel.isWarning
            || disk.isWarning
            || cpu.isSustainedOverload
            || battery.isWarning
    }

    /// SF Symbol name for the menu bar icon.
    var iconSymbolName: String {
        hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    /// Foreground color for the menu bar icon.
    /// Returns orange when any warning is active; nil defers to the system default
    /// (monochrome/template rendering for the current menu bar appearance).
    var iconColor: Color? {
        hasWarning ? .orange : nil
    }

    /// Tooltip text shown when hovering over the menu bar icon.
    /// Mirrors the disabled menu item lines; battery line is omitted when no battery is present.
    var tooltipString: String {
        var lines = [
            "Memory: \(memory.displayString)",
            "Disk: \(disk.displayString)",
            "CPU: \(cpu.displayString)",
        ]
        if battery.hasBattery {
            lines.append("Battery: \(battery.displayString)")
        }
        return lines.joined(separator: "\n")
    }

    static let initial = SystemStatus(
        memory: .unknown,
        disk: .unknown,
        cpu: .unknown,
        battery: .unknown
    )
}
