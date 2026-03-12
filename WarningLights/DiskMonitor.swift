import Foundation

/// Monitors boot volume disk usage.
final class DiskMonitor {

    // MARK: - Types

    struct Stats {
        let usedBytes: Int64
        let totalBytes: Int64

        var usedFraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(usedBytes) / Double(totalBytes)
        }

        var usedPercent: Int { Int(usedFraction * 100) }

        /// Warning triggers when usage exceeds 90%.
        var isWarning: Bool { usedFraction > 0.90 }

        var displayString: String {
            "\(usedPercent)% used (boot volume)"
        }

        static let unknown = Stats(usedBytes: 0, totalBytes: 0)
    }

    // MARK: - Properties

    private(set) var stats: Stats = .unknown

    // MARK: - Polling

    func refresh() {
        stats = readDiskStats()
    }

    // MARK: - Private

    private func readDiskStats() -> Stats {
        let fm = FileManager.default
        let bootURL = URL(fileURLWithPath: "/")

        // Use volumeAvailableCapacityForImportantUsage for accurate purgeable accounting.
        guard
            let resourceValues = try? bootURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey,
            ]),
            let totalCapacity = resourceValues.volumeTotalCapacity,
            let availableCapacity = resourceValues
                .volumeAvailableCapacityForImportantUsage
        else {
            // Fallback via FileManager attributes.
            return fallbackDiskStats(fm: fm)
        }

        let total = Int64(totalCapacity)
        let available = availableCapacity
        let used = total - available

        return Stats(usedBytes: max(0, used), totalBytes: total)
    }

    private func fallbackDiskStats(fm: FileManager) -> Stats {
        guard
            let attrs = try? fm.attributesOfFileSystem(forPath: "/"),
            let total = attrs[.systemSize] as? Int64,
            let free = attrs[.systemFreeSize] as? Int64
        else {
            return .unknown
        }
        return Stats(usedBytes: total - free, totalBytes: total)
    }
}
