import SwiftUI

@main
struct WarningLightsApp: App {

    @State private var monitor = SystemMonitor()

    init() {
        enforceSingleInstance()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(status: monitor.status)
                .task {
                    // Start monitoring when the app launches.
                    // The .task modifier runs on appearance; since this is a
                    // MenuBarExtra the task starts at app launch and lives for
                    // the entire app lifetime.
                    monitor.start()
                }
                .onChange(of: monitor.status.tooltipString, initial: true) { _, newValue in
                    // Defer to next run loop tick so the status bar button exists.
                    DispatchQueue.main.async {
                        StatusItemTooltip.update(newValue)
                    }
                }
        } label: {
            // When a warning is active, render the icon in orange so it stands
            // out against the menu bar. When all clear, use monochrome/template
            // rendering so the system automatically adapts to light/dark
            // backgrounds and tinted menu bars.
            Image(systemName: monitor.status.iconSymbolName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(monitor.status.iconColor ?? .primary)
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Single Instance Enforcement

    /// If another instance of this app is already running, terminate this one silently.
    private func enforceSingleInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? "net.kristopherjohnson.WarningLights"
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        )
        // `running` includes the current process; if count > 1 another instance exists.
        if running.count > 1 {
            NSApplication.shared.terminate(nil)
        }
    }
}
