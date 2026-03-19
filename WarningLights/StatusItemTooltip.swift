import AppKit

/// Sets the tooltip on the NSStatusBarButton created by SwiftUI's MenuBarExtra.
///
/// SwiftUI's `.help()` modifier and NSViewRepresentable do not work inside
/// `.menu`-style MenuBarExtra labels because the label is rendered as a static
/// NSImage. This uses KVC on the private NSStatusBarWindow to reach the
/// underlying NSStatusItem and set its button's toolTip directly.
@MainActor
enum StatusItemTooltip {

    static func update(_ text: String) {
        guard let button = findStatusBarButton() else { return }
        button.toolTip = text
    }

    private static func findStatusBarButton() -> NSStatusBarButton? {
        NSApp.windows
            .filter { $0.className.contains("NSStatusBarWindow") }
            .compactMap { $0.value(forKey: "statusItem") as? NSStatusItem }
            .first?
            .button
    }
}
