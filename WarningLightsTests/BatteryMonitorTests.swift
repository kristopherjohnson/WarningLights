import XCTest

@testable import WarningLights

final class BatteryMonitorTests: XCTestCase {

    func testStatsCapacityIsInValidRange() {
        let monitor = BatteryMonitor()
        monitor.refresh()
        XCTAssertGreaterThanOrEqual(monitor.stats.capacity, 0)
        XCTAssertLessThanOrEqual(monitor.stats.capacity, 100)
    }

    func testNoWarningWhenCharging() {
        let stats = BatteryMonitor.Stats(hasBattery: true, capacity: 10, isCharging: true)
        XCTAssertFalse(stats.isWarning)
    }

    func testWarningWhenLowOnBattery() {
        let stats = BatteryMonitor.Stats(hasBattery: true, capacity: 19, isCharging: false)
        XCTAssertTrue(stats.isWarning)
    }

    func testNoWarningAtTwentyPercent() {
        let stats = BatteryMonitor.Stats(hasBattery: true, capacity: 20, isCharging: false)
        XCTAssertFalse(stats.isWarning)
    }

    func testNoWarningWhenNoBattery() {
        XCTAssertFalse(BatteryMonitor.Stats.unknown.isWarning)
    }

    func testDisplayStringCharging() {
        let stats = BatteryMonitor.Stats(hasBattery: true, capacity: 85, isCharging: true)
        XCTAssertTrue(stats.displayString.contains("85"))
        XCTAssertTrue(stats.displayString.contains("charging"))
    }

    func testDisplayStringOnBattery() {
        let stats = BatteryMonitor.Stats(hasBattery: true, capacity: 42, isCharging: false)
        XCTAssertTrue(stats.displayString.contains("42"))
        XCTAssertFalse(stats.displayString.contains("charging"))
    }

    func testDisplayStringEmptyWhenNoBattery() {
        XCTAssertTrue(BatteryMonitor.Stats.unknown.displayString.isEmpty)
    }
}
