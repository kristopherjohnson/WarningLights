import Foundation
import AppKit

/// Actor that coordinates all system monitoring and publishes `SystemStatus` updates.
@MainActor
@Observable
final class SystemMonitor {

    // MARK: - Published State

    private(set) var status: SystemStatus = .initial

    // MARK: - Private

    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let cpuMonitor = CPUMonitor()
    private var pollingTimer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var powerOffObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    func start() {
        // Memory pressure is event-driven; set up callback on main queue.
        memoryMonitor.onChange = { [weak self] in
            self?.publishStatus()
        }
        memoryMonitor.start()

        // Prime CPU sampler (first call stores ticks; no usage value yet).
        cpuMonitor.refresh()
        diskMonitor.refresh()

        // Perform initial full poll after a brief delay so the CPU sampler
        // has two samples to diff.
        let initialDelay: TimeInterval = 2
        Timer.scheduledTimer(withTimeInterval: initialDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollAndPublish()
                self?.startPollingTimer()
            }
        }

        registerSystemNotifications()
    }

    func stop() {
        stopPollingTimer()
        memoryMonitor.stop()
        unregisterSystemNotifications()
    }

    // MARK: - Polling

    private func startPollingTimer() {
        stopPollingTimer()
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollAndPublish()
            }
        }
    }

    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollAndPublish() {
        memoryMonitor.refreshStats()
        diskMonitor.refresh()
        cpuMonitor.refresh()
        publishStatus()
    }

    private func publishStatus() {
        status = SystemStatus(
            memory: memoryMonitor.stats,
            disk: diskMonitor.stats,
            cpu: cpuMonitor.stats
        )
    }

    // MARK: - System Notifications

    private func registerSystemNotifications() {
        let workspace = NSWorkspace.shared
        let nc = workspace.notificationCenter

        sleepObserver = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleSleep()
            }
        }

        wakeObserver = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleWake()
            }
        }

        powerOffObserver = nc.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    private func unregisterSystemNotifications() {
        // terminateObserver was registered on NotificationCenter.default.
        [terminateObserver]
            .compactMap { $0 }
            .forEach { NotificationCenter.default.removeObserver($0) }

        // sleep/wake/powerOff observers were registered on the workspace notification center.
        [sleepObserver, wakeObserver, powerOffObserver]
            .compactMap { $0 }
            .forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }

        sleepObserver = nil
        wakeObserver = nil
        powerOffObserver = nil
        terminateObserver = nil
    }

    private func handleSleep() {
        stopPollingTimer()
    }

    private func handleWake() {
        // Re-prime the CPU sampler after wake — ticks will have jumped.
        cpuMonitor.refresh()

        // Start timer; first real poll fires after 2 seconds so CPU has two samples.
        let wakeDelay: TimeInterval = 2
        Timer.scheduledTimer(withTimeInterval: wakeDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollAndPublish()
                self?.startPollingTimer()
            }
        }
    }
}
