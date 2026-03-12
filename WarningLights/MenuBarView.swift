import SwiftUI

/// The content of the menu bar extra's drop-down menu.
struct MenuBarView: View {

    let status: SystemStatus

    var body: some View {
        // Memory status
        Text("Memory: \(status.memory.displayString)")
            .disabled(true)

        // Disk status
        Text("Disk: \(status.disk.displayString)")
            .disabled(true)

        // CPU status
        Text("CPU: \(status.cpu.displayString)")
            .disabled(true)

        Divider()

        // About item
        Button("About Warning Lights") {
            NSApplication.shared.orderFrontStandardAboutPanel()
        }

        // Quit
        Button("Quit Warning Lights") {
            NSApplication.shared.terminate(nil)
        }
    }
}
