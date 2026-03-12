# Warning Lights — Specification

## Overview

Warning Lights is a macOS menu bar application that monitors system health metrics and alerts the user when any metric is in a warning state. It runs silently in the background with no dock icon and no windows.

## Goals

- Provide unobtrusive, at-a-glance system health monitoring via the menu bar
- Alert users before macOS shows a "your machine has run out of application memory" dialog
- Surface disk, CPU, and application responsiveness issues proactively
- Follow macOS Human Interface Guidelines for menu bar extras

## Target Platforms

- macOS 26 (Tahoe) and newer
- Minimum deployment target: macOS 26.0
- Architecture: Apple Silicon and Intel (universal binary)

## Features

### Monitoring

| Metric | Warning Condition | Polling |
|--------|-------------------|---------|
| Memory | System memory pressure reaches `.warning` or `.critical` level | Event-driven via `DispatchSource.makeMemoryPressureSource`, supplemented by 60-second timer for UI refresh |
| Disk | Boot volume usage > 90% | Every 60 seconds |
| CPU | Sustained CPU usage > 75% (normalized 0–100% across all cores) for 10+ consecutive minutes | Every 60 seconds |

### Menu Bar Icon

- **All clear**: Displays a thumbs-up or checkmark SF Symbol (e.g., `checkmark.seal.fill` or `hand.thumbsup.fill`)
- **Warning active**: Displays a warning SF Symbol (e.g., `exclamationmark.triangle.fill`) or metric-specific icon
- Icon updates after each monitoring pass
- Icon uses `.monochrome` symbol rendering mode (equivalent to template rendering; respects system light/dark mode and tinted menu bar backgrounds)

### Menu (on click)

The menu displays:
- **Status items** (disabled, read-only) showing the most recent measurement for each metric:
  - Memory: pressure level ("Normal" / "Warning" / "Critical") and used/total bytes (e.g., "12.4 GB / 16 GB")
  - Disk: usage percentage for boot volume
  - CPU: current usage percentage (0–100%) and whether the 10-minute sustained threshold is active
- **Separator**
- **About Warning Lights** menu item — enabled; opens the standard macOS About panel (`NSApplication.orderFrontStandardAboutPanel`) showing app name, version, and copyright from Info.plist
- **Quit** menu item to terminate the app

### No Window

The application has no main window. It is a pure menu bar extra (`LSUIElement = YES` in Info.plist). It does not appear in the Dock or in the Command-Tab app switcher.

## User Interface

### SF Symbol Choices

| State | SF Symbol | Meaning |
|-------|-----------|---------|
| All clear | `checkmark.seal.fill` | Everything OK |
| Memory warning | `memorychip.fill` or `exclamationmark.triangle.fill` | Memory pressure high |
| Disk warning | `externaldrive.fill.badge.exclamationmark` | Disk nearly full |
| CPU warning | `cpu.fill` or `exclamationmark.triangle.fill` | CPU overloaded |
| Multiple warnings | `exclamationmark.triangle.fill` | General warning |

> **Open**: Final SF Symbol selection to be confirmed during implementation. Prefer symbols available in macOS 26 SDK.

### Menu Item Format

```
● Memory: Normal (10.2 GB / 16 GB)
● Disk: 78% used (boot volume)
● CPU: 45% (no sustained overload)
---
About Warning Lights
Quit Warning Lights
```

When a metric is in warning state, its menu item text reflects the issue clearly.

## Technical Requirements

### System Metrics Collection

- **Memory (pressure detection)**: Use `DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)` to receive kernel memory pressure events. This is the only public, supported API that reports the kernel's actual memory pressure determination. Three levels exist: `.normal`, `.warning`, `.critical` (Swift `DispatchSource.MemoryPressureEvent`). Trigger the warning icon at `.warning` — this is the "degrading but still usable" level. By `.critical`, the OOM dialog is imminent. Do NOT use percentage-based heuristics to determine alert state.
- **Memory (display stats)**: Use `host_statistics64` with `HOST_VM_INFO64` to read raw VM page counts (`free_count`, `active_count`, `inactive_count`, `wire_count`, `compressor_page_count`) for informational display in the menu. Multiply by `vm_kernel_page_size` for bytes. Use `ProcessInfo.processInfo.physicalMemory` for total RAM.
- **Disk**: Use `FileManager.default.volumeAvailableCapacityForImportantUsage` on the boot volume, or `statvfs` / `getattrlist`
- **CPU**: Use `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO` to read per-core tick counts (user, system, idle, nice). Sum deltas across all cores between two samples: `busy = Σ(Δuser + Δsystem + Δnice)`, `total = Σ(Δuser + Δsystem + Δidle + Δnice)`, `usage = busy / total` → normalized 0.0–1.0 (0–100%). Track a rolling window of 10 samples (10 × 60s = 10 minutes). Warning triggers when all 10 samples exceed 75%. Apple Silicon P-cores and E-cores are not distinguished by this API; the aggregate is correct. The returned `processor_info_array_t` must be freed with `vm_deallocate` after each sample.

### Architecture

- Swift with SwiftUI
- `MenuBarExtra` for the menu bar icon and menu
- `DispatchSource.makeMemoryPressureSource` for event-driven memory pressure detection
- `DispatchSourceTimer` (or `Timer`) for the 60-second polling interval (disk, CPU, and memory display stats)
- Separate `SystemMonitor` class/actor encapsulating metric collection logic
- `CPUUsageSampler` struct holding previous tick counts for computing deltas between samples
- Circular buffer (capacity 10) for CPU rolling window to detect sustained usage
- Metrics stored as a `SystemStatus` value type updated on each poll or memory pressure event

### Concurrency

- Metric collection runs on a background thread/actor
- UI updates (icon, menu) happen on the main thread
- Use Swift concurrency (`async/await`, `@MainActor`) where appropriate

### Permissions

- No special entitlements required for reading system metrics via public APIs
- Does not require sandboxing exceptions beyond standard macOS app defaults
- No network access needed

## Login Item Behavior

The app is intended to be added to macOS Login Items (System Settings → General → Login Items) by the user. It must behave correctly when launched this way:

- **Silent startup**: No splash screen, dialog, setup wizard, or any UI shown at launch. The menu bar icon appears and monitoring begins immediately.
- **Single instance**: If the app is already running and launched again (e.g., user double-clicks the bundle), the second instance must detect the first and quit without showing any UI or error.
- **Fast startup**: App must not stall the login process. Metric collection begins asynchronously; the icon is displayed promptly even before the first poll completes (showing a neutral/loading state if needed, or defaulting to all-clear until first data is available).
- **Clean shutdown**: Responds correctly to system logout, restart, and shutdown by stopping monitoring and terminating cleanly. Handle `NSWorkspace` power-off notifications to perform any necessary cleanup.
- **Wake from sleep**: Monitoring resumes correctly after the system wakes from sleep. The polling timer is restarted if it was suspended during sleep.

## Constraints

- No windows, no dock icon, no app switcher presence (`LSUIElement = YES`)
- Must not show an onboarding window or setup wizard
- Must compile and run on macOS 26+
- App bundle identifier: `com.kristopherjohnson.WarningLights` (or similar)
- No third-party dependencies; use only Apple frameworks

## Out of Scope

- iOS, iPadOS, watchOS, or other platforms
- Notifications (push or local) — icon change is the only alert mechanism
- User-configurable thresholds
- Historical logging or charts
- Network monitoring
- Battery monitoring
- Programmatic registration/deregistration of the login item (user manages this via System Settings)
