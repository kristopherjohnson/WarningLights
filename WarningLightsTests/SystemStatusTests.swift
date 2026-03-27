import SwiftUI
import XCTest

@testable import WarningLights

// MARK: - SystemStatus Warning Flag Tests (6.2)

final class SystemStatusWarningTests: XCTestCase {

    // MARK: Helpers

    private func makeStatus(
        memoryPressure: MemoryMonitor.PressureLevel = .normal,
        diskUsedBytes: Int64 = 50,
        diskTotalBytes: Int64 = 100,
        cpuCurrentUsage: Double = 0.0,
        cpuIsSustainedOverload: Bool = false,
        battery: BatteryMonitor.Stats = .unknown
    ) -> SystemStatus {
        SystemStatus(
            memory: MemoryMonitor.Stats(
                pressureLevel: memoryPressure,
                usedBytes: 4 * 1_073_741_824,
                totalBytes: 8 * 1_073_741_824
            ),
            disk: DiskMonitor.Stats(
                usedBytes: diskUsedBytes,
                totalBytes: diskTotalBytes
            ),
            cpu: CPUMonitor.Stats(
                currentUsage: cpuCurrentUsage,
                isSustainedOverload: cpuIsSustainedOverload
            ),
            battery: battery
        )
    }

    // MARK: hasWarning — all-clear

    func testHasWarningFalseWhenAllClear() {
        let status = makeStatus(
            memoryPressure: .normal,
            diskUsedBytes: 50,
            diskTotalBytes: 100,
            cpuCurrentUsage: 0.5,
            cpuIsSustainedOverload: false
        )
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when all monitors are healthy")
    }

    // MARK: hasWarning — memory triggers

    func testHasWarningFalseWhenMemoryWarning() {
        let status = makeStatus(memoryPressure: .warning)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when memory pressure is .warning (only .critical triggers)")
    }

    func testHasWarningTrueWhenMemoryCritical() {
        let status = makeStatus(memoryPressure: .critical)
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when memory pressure is .critical")
    }

    func testHasWarningFalseWhenMemoryNormal() {
        let status = makeStatus(memoryPressure: .normal)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when memory pressure is .normal (other metrics healthy)")
    }

    // MARK: hasWarning — disk triggers

    func testHasWarningTrueWhenDiskAbove90Percent() {
        // 91/100 = 91%
        let status = makeStatus(diskUsedBytes: 91, diskTotalBytes: 100)
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when disk usage > 90%")
    }

    func testHasWarningFalseWhenDiskAt90Percent() {
        // exactly 90% — not above threshold
        let status = makeStatus(diskUsedBytes: 90, diskTotalBytes: 100)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when disk usage == 90%")
    }

    func testHasWarningFalseWhenDiskBelow90Percent() {
        let status = makeStatus(diskUsedBytes: 50, diskTotalBytes: 100)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when disk usage < 90%")
    }

    // MARK: hasWarning — CPU triggers

    func testHasWarningTrueWhenCPUSustainedOverload() {
        let status = makeStatus(cpuIsSustainedOverload: true)
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when CPU is in sustained overload")
    }

    func testHasWarningFalseWhenCPUNotSustainedOverload() {
        let status = makeStatus(cpuCurrentUsage: 0.99, cpuIsSustainedOverload: false)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when CPU is high but not sustained overload (other metrics healthy)")
    }

    // MARK: hasWarning — battery triggers

    func testHasWarningTrueWhenBatteryLowOnBatteryPower() {
        let status = makeStatus(
            battery: BatteryMonitor.Stats(hasBattery: true, capacity: 10, isCharging: false)
        )
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when battery is low and on battery power")
    }

    func testHasWarningFalseWhenBatteryLowButCharging() {
        let status = makeStatus(
            battery: BatteryMonitor.Stats(hasBattery: true, capacity: 10, isCharging: true)
        )
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when battery is low but charging")
    }

    func testHasWarningFalseWhenNoBattery() {
        let status = makeStatus(battery: .unknown)
        XCTAssertFalse(status.hasWarning,
            "hasWarning should be false when there is no battery")
    }

    // MARK: hasWarning — combined

    func testHasWarningTrueWhenMultipleWarnings() {
        let status = makeStatus(
            memoryPressure: .critical,
            diskUsedBytes: 95,
            diskTotalBytes: 100,
            cpuIsSustainedOverload: true
        )
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when all monitors are warning")
    }
}

// MARK: - Icon Selection Logic Tests (6.3)

final class IconSelectionTests: XCTestCase {

    private func makeStatus(hasWarning: Bool) -> SystemStatus {
        SystemStatus(
            memory: MemoryMonitor.Stats(
                pressureLevel: hasWarning ? .critical : .normal,
                usedBytes: 0,
                totalBytes: 0
            ),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false),
            battery: .unknown
        )
    }

    func testIconIsCheckmarkWhenAllClear() {
        let status = makeStatus(hasWarning: false)
        XCTAssertEqual(status.iconSymbolName, "checkmark.circle.fill",
            "All-clear state should use checkmark.circle.fill symbol")
    }

    func testIconIsExclamationWhenWarning() {
        let status = makeStatus(hasWarning: true)
        XCTAssertEqual(status.iconSymbolName, "exclamationmark.triangle.fill",
            "Warning state should use exclamationmark.triangle.fill symbol")
    }

    func testIconChangesFromClearToWarningWhenMemoryPressureSet() {
        let clear = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .normal, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false),
            battery: .unknown
        )
        let warning = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .critical, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false),
            battery: .unknown
        )
        XCTAssertNotEqual(clear.iconSymbolName, warning.iconSymbolName,
            "Icon symbol must differ between all-clear and critical states")
    }

    func testIconForDiskWarning() {
        let status = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .normal, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 95, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false),
            battery: .unknown
        )
        XCTAssertEqual(status.iconSymbolName, "exclamationmark.triangle.fill",
            "Disk > 90% should trigger the warning icon")
    }

    func testIconForCPUSustainedOverload() {
        let status = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .normal, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0.9, isSustainedOverload: true),
            battery: .unknown
        )
        XCTAssertEqual(status.iconSymbolName, "exclamationmark.triangle.fill",
            "CPU sustained overload should trigger the warning icon")
    }

    func testInitialStatusIconIsAllClear() {
        // The .initial static value should start with all-clear icon.
        XCTAssertEqual(SystemStatus.initial.iconSymbolName, "checkmark.circle.fill",
            "Initial status should show the all-clear icon")
    }

    // MARK: Icon color

    func testIconColorIsNilWhenAllClear() {
        let status = makeStatus(hasWarning: false)
        XCTAssertNil(status.iconColor,
            "All-clear state should return nil iconColor (monochrome/template rendering)")
    }

    func testIconColorIsOrangeWhenWarning() {
        let status = makeStatus(hasWarning: true)
        XCTAssertEqual(status.iconColor, .orange,
            "Warning state should return orange iconColor")
    }

    func testIconColorIsNilForInitialStatus() {
        XCTAssertNil(SystemStatus.initial.iconColor,
            "Initial status should use monochrome rendering (nil color)")
    }
}

// MARK: - Tooltip String Tests (4.7)

final class TooltipStringTests: XCTestCase {

    private func makeStatus(hasBattery: Bool) -> SystemStatus {
        SystemStatus(
            memory: MemoryMonitor.Stats(
                pressureLevel: .normal,
                usedBytes: UInt64(4 * 1_073_741_824),
                totalBytes: UInt64(16 * 1_073_741_824)
            ),
            disk: DiskMonitor.Stats(usedBytes: 78, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0.45, isSustainedOverload: false),
            battery: hasBattery
                ? BatteryMonitor.Stats(hasBattery: true, capacity: 85, isCharging: true)
                : .unknown
        )
    }

    func testTooltipContainsMemoryLine() {
        let status = makeStatus(hasBattery: false)
        XCTAssertTrue(status.tooltipString.contains("Memory:"),
            "Tooltip must include a Memory line")
    }

    func testTooltipContainsDiskLine() {
        let status = makeStatus(hasBattery: false)
        XCTAssertTrue(status.tooltipString.contains("Disk:"),
            "Tooltip must include a Disk line")
    }

    func testTooltipContainsCPULine() {
        let status = makeStatus(hasBattery: false)
        XCTAssertTrue(status.tooltipString.contains("CPU:"),
            "Tooltip must include a CPU line")
    }

    func testTooltipOmitsBatteryLineWhenNoBattery() {
        let status = makeStatus(hasBattery: false)
        XCTAssertFalse(status.tooltipString.contains("Battery:"),
            "Tooltip must not include a Battery line when no battery is present")
    }

    func testTooltipIncludesBatteryLineWhenHasBattery() {
        let status = makeStatus(hasBattery: true)
        XCTAssertTrue(status.tooltipString.contains("Battery:"),
            "Tooltip must include a Battery line when battery is present")
    }

    func testTooltipMatchesMenuItemFormats() {
        let status = makeStatus(hasBattery: true)
        // Each line should mirror the corresponding disabled menu item text.
        XCTAssertTrue(status.tooltipString.contains(status.memory.displayString))
        XCTAssertTrue(status.tooltipString.contains(status.disk.displayString))
        XCTAssertTrue(status.tooltipString.contains(status.cpu.displayString))
        XCTAssertTrue(status.tooltipString.contains(status.battery.displayString))
    }
}
