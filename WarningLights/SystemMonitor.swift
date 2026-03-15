import Foundation
import AppKit
import UserNotifications

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
    private let batteryMonitor = BatteryMonitor()
    private var pollingTimer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var powerOffObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var hasHadFirstPoll: Bool = false
    private var previousHasWarning: Bool = false

    // MARK: - Lifecycle

    func start() {
        requestNotificationAuthorization()

        // Memory pressure is event-driven; set up callback on main queue.
        memoryMonitor.onChange = { [weak self] in
            self?.publishStatus()
        }
        memoryMonitor.start()

        batteryMonitor.onChange = { [weak self] in
            self?.publishStatus()
        }
        batteryMonitor.start()

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
        batteryMonitor.stop()
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
        batteryMonitor.refresh()
        publishStatus()
    }

    private func publishStatus() {
        let oldHasWarning = previousHasWarning
        let newStatus = SystemStatus(
            memory: memoryMonitor.stats,
            disk: diskMonitor.stats,
            cpu: cpuMonitor.stats,
            battery: batteryMonitor.stats
        )
        status = newStatus
        previousHasWarning = newStatus.hasWarning

        guard hasHadFirstPoll else {
            hasHadFirstPoll = true
            return
        }

        if !oldHasWarning && newStatus.hasWarning {
            postWarningNotification(status: newStatus)
        } else if oldHasWarning && !newStatus.hasWarning {
            postRecoveryNotification()
        }
    }

    // MARK: - User Notifications

    private func requestNotificationAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            // Permission denied or granted — app continues silently either way.
        }
    }

    private func postWarningNotification(status: SystemStatus) {
        var reasons: [String] = []
        if status.memory.pressureLevel.isWarning {
            reasons.append("Memory pressure is high.")
        }
        if status.disk.isWarning {
            reasons.append("Disk is nearly full.")
        }
        if status.cpu.isSustainedOverload {
            reasons.append("CPU is overloaded.")
        }
        if status.battery.isWarning {
            reasons.append("Battery is low.")
        }
        let body = reasons.joined(separator: " ")
        postNotification(title: "Warning Lights", body: body)
    }

    private func postRecoveryNotification() {
        postNotification(title: "Warning Lights", body: "System is healthy again.")
    }

    private func postNotification(title: String, body: String) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            let center = UNUserNotificationCenter.current()
            try? await center.add(request)
            // Delivery failures are ignored; the app continues silently.
        }
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
