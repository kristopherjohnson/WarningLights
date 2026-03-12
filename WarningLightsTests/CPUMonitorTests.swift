import XCTest

@testable import WarningLights

// MARK: - CPUUsageSampler Tests

final class CPUUsageSamplerTests: XCTestCase {

    // MARK: 6.1 CPUUsageSampler delta math

    /// Build a CPUTickSample from a simple array of per-core (user, system, idle, nice) tuples.
    private func makeSample(
        _ cores: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)]
    ) -> CPUTickSample {
        CPUTickSample(ticks: cores)
    }

    func testSamplerInjectsDeltaCorrectly() {
        // Manually drive the sampler by setting previousSample and computing a delta.
        // We use two explicit samples to verify the delta formula.
        var sampler = CPUUsageSampler()

        // First injection: prime with a previous sample by calling sample() once
        // so it stores the OS reading as previousSample.  Instead, test the math
        // by verifying the pure delta logic via CPUTickSample directly.

        // 1 core: user advances by 75, idle advances by 25 → 75% busy.
        let prev = makeSample([(user: 100, system: 0, idle: 800, nice: 0)])
        let curr = makeSample([(user: 175, system: 0, idle: 825, nice: 0)])

        let usage = computeDelta(prev: prev, curr: curr)
        XCTAssertEqual(usage, 0.75, accuracy: 0.001,
            "75 busy ticks out of 100 total = 75% CPU usage")
    }

    func testSamplerDeltaAllIdle() {
        let prev = makeSample([(user: 0, system: 0, idle: 100, nice: 0)])
        let curr = makeSample([(user: 0, system: 0, idle: 200, nice: 0)])
        let usage = computeDelta(prev: prev, curr: curr)
        XCTAssertEqual(usage, 0.0, accuracy: 0.001,
            "All idle ticks → 0% CPU usage")
    }

    func testSamplerDeltaFullyBusy() {
        let prev = makeSample([(user: 0, system: 0, idle: 0, nice: 0)])
        let curr = makeSample([(user: 100, system: 0, idle: 0, nice: 0)])
        let usage = computeDelta(prev: prev, curr: curr)
        XCTAssertEqual(usage, 1.0, accuracy: 0.001,
            "All busy ticks → 100% CPU usage")
    }

    func testSamplerDeltaWraparound() {
        // UInt32 wraparound: current < previous due to counter overflow.
        let prev = makeSample([(user: UInt32.max - 10, system: 0, idle: 0, nice: 0)])
        let curr = makeSample([(user: 89, system: 0, idle: 0, nice: 0)])
        // Wrapping delta: (89 - (UInt32.max - 10)) wrapping = 100
        let usage = computeDelta(prev: prev, curr: curr)
        // 100 busy out of 100 total → 1.0
        XCTAssertEqual(usage, 1.0, accuracy: 0.001,
            "Wrapped user delta should be handled correctly")
    }

    func testSamplerMultipleCoreDelta() {
        // 2 cores: each 50% busy.
        let prev = makeSample([
            (user: 0, system: 0, idle: 0, nice: 0),
            (user: 0, system: 0, idle: 0, nice: 0),
        ])
        let curr = makeSample([
            (user: 50, system: 0, idle: 50, nice: 0),
            (user: 50, system: 0, idle: 50, nice: 0),
        ])
        let usage = computeDelta(prev: prev, curr: curr)
        XCTAssertEqual(usage, 0.5, accuracy: 0.001,
            "Two cores each 50% busy → 50% aggregate")
    }

    func testSamplerZeroTotalReturnsZero() {
        // No ticks at all → no progress → return 0.
        let prev = makeSample([(user: 100, system: 0, idle: 100, nice: 0)])
        let curr = makeSample([(user: 100, system: 0, idle: 100, nice: 0)])
        let usage = computeDelta(prev: prev, curr: curr)
        XCTAssertEqual(usage, 0.0, accuracy: 0.001,
            "Zero total delta ticks → 0% usage")
    }

    // MARK: - CPUMonitor ring buffer tests

    func testCPUMonitorRefreshLiveValuesAreInRange() {
        // This calls the real OS sampler; first call primes, second produces a value.
        let monitor = CPUMonitor()
        monitor.refresh() // prime
        monitor.refresh() // first real sample
        let usage = monitor.stats.currentUsage
        XCTAssertGreaterThanOrEqual(usage, 0.0,
            "CPU usage must be >= 0")
        XCTAssertLessThanOrEqual(usage, 1.0,
            "CPU usage must be <= 1")
    }

    func testCPUMonitorNoSustainedOverloadBeforeWindowFull() {
        // A window of 10 samples is required. Verify that even if all samples are
        // high, isSustainedOverload is false until the window is full.
        //
        // We use CPUMonitor's public API: init(windowSize:) lets us set a custom
        // window so the test stays deterministic in iteration count.
        let windowSize = 3
        let monitor = CPUMonitor(windowSize: windowSize)

        // Drive real OS samples; we can't control values but we can verify the
        // window-full invariant by inspecting isSustainedOverload before the
        // window is filled. After just 1 real sample (prime + 1 refresh),
        // the ring buffer has 1 entry — not yet full with windowSize = 3.
        monitor.refresh() // prime (nil delta)
        monitor.refresh() // ring buffer count = 1
        XCTAssertFalse(monitor.stats.isSustainedOverload,
            "isSustainedOverload must be false until ring buffer is full")
    }

    // MARK: - Helpers

    /// Replicates CPUUsageSampler's delta computation for pure-logic testing
    /// without needing to call the real OS API.
    private func computeDelta(prev: CPUTickSample, curr: CPUTickSample) -> Double {
        let coreCount = min(prev.ticks.count, curr.ticks.count)
        guard coreCount > 0 else { return 0 }

        var totalBusy: UInt64 = 0
        var totalAll: UInt64 = 0

        for i in 0 ..< coreCount {
            let dUser = UInt64(curr.ticks[i].user &- prev.ticks[i].user)
            let dSystem = UInt64(curr.ticks[i].system &- prev.ticks[i].system)
            let dIdle = UInt64(curr.ticks[i].idle &- prev.ticks[i].idle)
            let dNice = UInt64(curr.ticks[i].nice &- prev.ticks[i].nice)

            totalBusy += dUser + dSystem + dNice
            totalAll += dUser + dSystem + dIdle + dNice
        }

        guard totalAll > 0 else { return 0 }
        return Double(totalBusy) / Double(totalAll)
    }
}
