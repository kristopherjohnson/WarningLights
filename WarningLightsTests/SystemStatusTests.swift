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
        cpuIsSustainedOverload: Bool = false
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
            )
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

    func testHasWarningTrueWhenMemoryWarning() {
        let status = makeStatus(memoryPressure: .warning)
        XCTAssertTrue(status.hasWarning,
            "hasWarning should be true when memory pressure is .warning")
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
                pressureLevel: hasWarning ? .warning : .normal,
                usedBytes: 0,
                totalBytes: 0
            ),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false)
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
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false)
        )
        let warning = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .warning, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false)
        )
        XCTAssertNotEqual(clear.iconSymbolName, warning.iconSymbolName,
            "Icon symbol must differ between all-clear and warning states")
    }

    func testIconForDiskWarning() {
        let status = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .normal, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 95, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0, isSustainedOverload: false)
        )
        XCTAssertEqual(status.iconSymbolName, "exclamationmark.triangle.fill",
            "Disk > 90% should trigger the warning icon")
    }

    func testIconForCPUSustainedOverload() {
        let status = SystemStatus(
            memory: MemoryMonitor.Stats(pressureLevel: .normal, usedBytes: 0, totalBytes: 0),
            disk: DiskMonitor.Stats(usedBytes: 0, totalBytes: 100),
            cpu: CPUMonitor.Stats(currentUsage: 0.9, isSustainedOverload: true)
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
