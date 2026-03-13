# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```sh
make help       # Show all available targets
make build      # Build Release into build/
make run        # Build and launch
make test       # Run all unit tests
make install    # Build and copy to /Applications
make uninstall  # Kill running instances and remove from /Applications
make kill       # Kill any running instances
make clean      # Delete build artifacts

# Run a single test class
xcodebuild -project WarningLights.xcodeproj -scheme WarningLights \
    -only-testing:WarningLightsTests/CPUUsageSamplerTests test

# Run a single test method
xcodebuild -project WarningLights.xcodeproj -scheme WarningLights \
    -only-testing:WarningLightsTests/SystemStatusWarningTests/testNoWarningsWhenAllClear test
```

Swift 6 strict concurrency is enabled. The deployment target is macOS 26.0. No third-party dependencies.

## Architecture

Menu-bar-only app (`LSUIElement = YES`). No windows, no dock icon.

```
WarningLightsApp (@main)
  └─ SystemMonitor (@MainActor, @Observable)
       ├─ MemoryMonitor  — event-driven (DispatchSourceMemoryPressure) + 60s polling for VM stats
       ├─ DiskMonitor     — 60s polling via FileManager (boot volume only)
       ├─ CPUMonitor      — 60s polling via host_processor_info, 10-sample ring buffer
       └─ status: SystemStatus → drives MenuBarExtra icon + MenuBarView
```

**Data flow**: Monitors collect raw metrics → `SystemMonitor.pollAndPublish()` aggregates into `SystemStatus` → SwiftUI reactivity (`@Observable`) updates the menu bar icon and dropdown menu.

**Icon color**: The menu bar icon uses monochrome/template rendering (standard menu bar color) when all clear, and orange when any warning is active. Controlled by `SystemStatus.iconColor` applied via `.foregroundStyle()` on the `MenuBarExtra` label.

**Concurrency model**: All mutable state lives on `@MainActor` in `SystemMonitor`. Timer and notification callbacks use `MainActor.assumeIsolated` to dispatch back. Memory pressure uses a `DispatchSource` on the main queue. No shared mutable state outside `SystemMonitor`.

**Warning thresholds**: Memory at `.warning`/`.critical` pressure (kernel-driven, not percentage), disk > 90% used, CPU > 75% sustained across all 10 rolling samples (10 minutes).

## Key Patterns

- **Mach API cleanup**: `host_processor_info` returns a `processor_info_array_t` that must be freed with `vm_deallocate`. CPU tick deltas use `&-` for UInt32 wraparound.
- **Initial delay**: CPU sampler needs two samples to compute a delta, so first real poll fires after a 2-second delay.
- **Sleep/wake**: Polling timer stops on sleep, restarts on wake with a fresh CPU prime.
- **Single instance**: Checks `NSRunningApplication` by bundle ID at launch; terminates silently if duplicate.

## Tests

Tests call real OS APIs and validate postconditions (ranges, invariants) rather than mocking. Test classes:
- `MemoryMonitorTests`, `DiskMonitorTests` — stats sanity checks, threshold logic
- `CPUUsageSamplerTests` — delta math, ring buffer, UInt32 wraparound
- `SystemStatusWarningTests` — warning flag aggregation
- `IconSelectionTests` — SF Symbol selection based on warning state
