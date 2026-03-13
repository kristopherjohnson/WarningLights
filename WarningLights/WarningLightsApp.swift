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
        } label: {
            // Use .template rendering so the system automatically inverts the
            // icon for light/dark menu bar backgrounds and tinted backgrounds.
            Image(systemName: monitor.status.iconSymbolName)
                .symbolRenderingMode(.monochrome)
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
