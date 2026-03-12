import Darwin
import Foundation

/// Holds per-core tick counts from a single `host_processor_info` sample.
struct CPUTickSample {
    let ticks: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)]

    static let empty = CPUTickSample(ticks: [])
}

/// Computes CPU usage delta between two tick samples, normalized 0.0–1.0.
struct CPUUsageSampler {

    private(set) var previousSample: CPUTickSample = .empty

    /// Returns normalized CPU usage (0.0–1.0) relative to the previous sample,
    /// and stores the new sample for the next call.
    mutating func sample() -> Double? {
        guard let newSample = readTickSample() else { return nil }
        defer { previousSample = newSample }

        guard !previousSample.ticks.isEmpty else {
            // First sample — no delta available yet.
            return nil
        }

        let prev = previousSample.ticks
        let curr = newSample.ticks
        let coreCount = min(prev.count, curr.count)
        guard coreCount > 0 else { return nil }

        var totalBusy: UInt64 = 0
        var totalAll: UInt64 = 0

        for i in 0 ..< coreCount {
            // Deltas — handle wraparound.
            let dUser = UInt64(wrappingDelta(curr[i].user, prev[i].user))
            let dSystem = UInt64(wrappingDelta(curr[i].system, prev[i].system))
            let dIdle = UInt64(wrappingDelta(curr[i].idle, prev[i].idle))
            let dNice = UInt64(wrappingDelta(curr[i].nice, prev[i].nice))

            totalBusy += dUser + dSystem + dNice
            totalAll += dUser + dSystem + dIdle + dNice
        }

        guard totalAll > 0 else { return 0 }
        return Double(totalBusy) / Double(totalAll)
    }

    private func wrappingDelta(_ current: UInt32, _ previous: UInt32) -> UInt32 {
        // UInt32 subtraction wraps naturally (modular arithmetic).
        current &- previous
    }

    private func readTickSample() -> CPUTickSample? {
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS,
            let info = processorInfo
        else { return nil }

        defer {
            // Must deallocate the returned array to avoid memory leaks.
            let size = vm_size_t(processorMsgCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let strideCount = Int(CPU_STATE_MAX)
        var ticks: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
        ticks.reserveCapacity(Int(processorCount))

        for i in 0 ..< Int(processorCount) {
            let base = i * strideCount
            let user = UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            ticks.append((user: user, system: system, idle: idle, nice: nice))
        }

        return CPUTickSample(ticks: ticks)
    }
}

/// Monitors CPU usage using a rolling ring buffer of 10 samples.
final class CPUMonitor {

    // MARK: - Types

    struct Stats {
        /// Most recent CPU usage, 0.0–1.0.
        let currentUsage: Double
        /// True when all 10 rolling samples exceed the threshold.
        let isSustainedOverload: Bool

        var usagePercent: Int { Int(currentUsage * 100) }

        var displayString: String {
            if isSustainedOverload {
                return "\(usagePercent)% (sustained overload)"
            } else {
                return "\(usagePercent)% (no sustained overload)"
            }
        }

        static let unknown = Stats(currentUsage: 0, isSustainedOverload: false)
    }

    // MARK: - Configuration

    /// Warning triggers when all samples in the rolling window exceed this fraction.
    static let overloadThreshold: Double = 0.75
    /// Number of consecutive samples required to declare sustained overload.
    static let rollingWindowSize: Int = 10

    // MARK: - Properties

    private(set) var stats: Stats = .unknown
    private var sampler = CPUUsageSampler()
    private var ringBuffer: [Double] = []
    private let windowSize: Int

    init(windowSize: Int = CPUMonitor.rollingWindowSize) {
        self.windowSize = windowSize
    }

    // MARK: - Polling

    func refresh() {
        guard let usage = sampler.sample() else {
            // Not enough data yet (first call primes the sampler).
            return
        }

        // Append to ring buffer, capping at windowSize.
        ringBuffer.append(usage)
        if ringBuffer.count > windowSize {
            ringBuffer.removeFirst()
        }

        let isSustained =
            ringBuffer.count == windowSize
            && ringBuffer.allSatisfy { $0 > Self.overloadThreshold }

        stats = Stats(currentUsage: usage, isSustainedOverload: isSustained)
    }
}
