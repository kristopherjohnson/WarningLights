import XCTest

@testable import WarningLights

// MARK: - MemoryMonitor Tests

final class MemoryMonitorTests: XCTestCase {

    // MARK: 6.1 MemoryMonitor

    func testMemoryStatsReturnsSensibleValues() {
        // MemoryMonitor.readVMStats() calls real OS APIs; verify postconditions
        // without mocking the kernel — we just check the contract holds.
        let monitor = MemoryMonitor()
        monitor.refreshStats()

        let stats = monitor.stats
        // totalBytes should equal the physical RAM reported by ProcessInfo.
        XCTAssertEqual(stats.totalBytes, ProcessInfo.processInfo.physicalMemory,
            "totalBytes should equal physical memory")
        // Used bytes must not exceed total bytes.
        XCTAssertLessThanOrEqual(stats.usedBytes, stats.totalBytes,
            "usedBytes must not exceed totalBytes")
        // Total must be positive on any real machine.
        XCTAssertGreaterThan(stats.totalBytes, 0,
            "totalBytes must be > 0")
    }

    func testMemoryStatsUsedBytesIsNonNegative() {
        let monitor = MemoryMonitor()
        monitor.refreshStats()
        XCTAssertGreaterThanOrEqual(monitor.stats.usedBytes, 0,
            "usedBytes must be non-negative")
    }

    func testPressureLevelNormalIsNotWarning() {
        XCTAssertFalse(MemoryMonitor.PressureLevel.normal.isWarning)
    }

    func testPressureLevelWarningIsWarning() {
        XCTAssertTrue(MemoryMonitor.PressureLevel.warning.isWarning)
    }

    func testPressureLevelCriticalIsWarning() {
        XCTAssertTrue(MemoryMonitor.PressureLevel.critical.isWarning)
    }

    func testDisplayStringContainsPressureLevelName() {
        let stats = MemoryMonitor.Stats(
            pressureLevel: .warning,
            usedBytes: 4 * 1_073_741_824,
            totalBytes: 8 * 1_073_741_824
        )
        XCTAssertTrue(stats.displayString.contains("Warning"),
            "displayString should contain pressure level name")
    }

    func testDisplayStringContainsGBValues() {
        let stats = MemoryMonitor.Stats(
            pressureLevel: .normal,
            usedBytes: 2 * 1_073_741_824,
            totalBytes: 8 * 1_073_741_824
        )
        XCTAssertTrue(stats.displayString.contains("2.0 GB"),
            "displayString should show used GB")
        XCTAssertTrue(stats.displayString.contains("8.0 GB"),
            "displayString should show total GB")
    }

    func testUnknownStatsHaveZeroBytes() {
        let unknown = MemoryMonitor.Stats.unknown
        XCTAssertEqual(unknown.usedBytes, 0)
        XCTAssertEqual(unknown.totalBytes, 0)
    }
}

// MARK: - DiskMonitor Tests

final class DiskMonitorTests: XCTestCase {

    // MARK: 6.1 DiskMonitor

    func testDiskStatsReturnsSensibleValues() {
        let monitor = DiskMonitor()
        monitor.refresh()

        let stats = monitor.stats
        XCTAssertGreaterThan(stats.totalBytes, 0,
            "totalBytes must be > 0")
        XCTAssertLessThanOrEqual(stats.usedBytes, stats.totalBytes,
            "usedBytes must not exceed totalBytes")
        XCTAssertGreaterThanOrEqual(stats.usedBytes, 0,
            "usedBytes must be non-negative")
    }

    func testDiskUsedPercentInValidRange() {
        let monitor = DiskMonitor()
        monitor.refresh()
        let pct = monitor.stats.usedPercent
        XCTAssertGreaterThanOrEqual(pct, 0,
            "usedPercent must be >= 0")
        XCTAssertLessThanOrEqual(pct, 100,
            "usedPercent must be <= 100")
    }

    func testDiskUsedFractionInValidRange() {
        let monitor = DiskMonitor()
        monitor.refresh()
        let frac = monitor.stats.usedFraction
        XCTAssertGreaterThanOrEqual(frac, 0.0)
        XCTAssertLessThanOrEqual(frac, 1.0)
    }

    func testDiskIsWarningAbove90Percent() {
        let stats = DiskMonitor.Stats(usedBytes: 91, totalBytes: 100)
        XCTAssertTrue(stats.isWarning,
            "isWarning should be true when usage > 90%")
    }

    func testDiskIsNotWarningAt90Percent() {
        let stats = DiskMonitor.Stats(usedBytes: 90, totalBytes: 100)
        XCTAssertFalse(stats.isWarning,
            "isWarning should be false at exactly 90%")
    }

    func testDiskIsNotWarningBelow90Percent() {
        let stats = DiskMonitor.Stats(usedBytes: 50, totalBytes: 100)
        XCTAssertFalse(stats.isWarning,
            "isWarning should be false when usage <= 90%")
    }

    func testDiskUsedFractionZeroWhenTotalIsZero() {
        let stats = DiskMonitor.Stats(usedBytes: 0, totalBytes: 0)
        XCTAssertEqual(stats.usedFraction, 0,
            "usedFraction should be 0 when totalBytes is 0")
    }

    func testDiskDisplayStringContainsPercent() {
        let stats = DiskMonitor.Stats(usedBytes: 50, totalBytes: 100)
        XCTAssertTrue(stats.displayString.contains("50%"),
            "displayString should contain percent value")
    }

    func testUnknownDiskStatsHaveZeroBytes() {
        let unknown = DiskMonitor.Stats.unknown
        XCTAssertEqual(unknown.usedBytes, 0)
        XCTAssertEqual(unknown.totalBytes, 0)
    }
}
