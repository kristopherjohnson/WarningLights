# Decision Log

2026-03-11 00:00 | SPECIFICATION.md | App named "Warning Lights"; macOS menu-bar-only app; monitors memory, disk (>90%), CPU (>100% for >10min), ANR; no windows; macOS 26+ target
2026-03-11 00:00 | SPECIFICATION.md | Menu shows most recent metric measurements as disabled items plus Quit item
2026-03-11 00:00 | SPECIFICATION.md | Use SF Symbols for icons; all-clear icon when healthy; warning icon when any metric is in warning state
2026-03-11 00:00 | SPECIFICATION.md | No third-party dependencies; no user-configurable thresholds; no notifications; no dock icon
2026-03-11 00:01 | SPECIFICATION.md | CPU threshold set to 75% of full-load capacity (all cores), not a flat 100%
2026-03-11 00:01 | SPECIFICATION.md | Memory warning triggers at "warn" pressure level (not just "critical")
2026-03-11 00:01 | SPECIFICATION.md | Use SwiftUI MenuBarExtra (not AppKit NSStatusItem)
2026-03-11 00:01 | SPECIFICATION.md | ANR detection covers any hung app (foreground or background)
2026-03-11 00:02 | SPECIFICATION.md | App will be added to Login Items by user; must start silently, enforce single instance, handle sleep/wake, and terminate cleanly on logout
2026-03-11 12:00 | SPECIFICATION.md | Confirmed bundle identifier: com.kristopherjohnson.WarningLights
2026-03-11 12:00 | SPECIFICATION.md | Add "About" menu item showing app name + version
2026-03-11 12:00 | OPEN_ISSUES.md | SF Symbol choices accepted as proposed; finalize during implementation
2026-03-11 | SPECIFICATION.md, IMPLEMENTATION_PLAN.md, TEST_PLAN.md, OPEN_ISSUES.md | Removed ANR (App Not Responding) detection feature entirely; app now monitors memory, disk, and CPU only
2026-03-11 | SPECIFICATION.md | Memory: use DispatchSource.makeMemoryPressureSource for pressure detection (.normal/.warning/.critical); alert at .warning level; use host_statistics64 only for display stats; do not use percentage heuristics for alert triggering
2026-03-11 | SPECIFICATION.md | CPU: use host_processor_info with PROCESSOR_CPU_LOAD_INFO; normalize tick deltas to 0-100% across all cores; 75% threshold with all-10-samples rolling window; vm_deallocate required after each sample; P/E core distinction not needed
2026-03-11 | IMPLEMENTATION_PLAN.md | Memory monitoring is event-driven (dispatch source) + 60s timer for display refresh; CPU monitoring is poll-based with CPUUsageSampler struct and ring buffer
2026-03-12 15:45 | SPECIFICATION.md, TEST_PLAN.md | About menu item is enabled and opens NSApplication.orderFrontStandardAboutPanel (not a disabled label)
2026-03-12 15:45 | SPECIFICATION.md | Icon uses .monochrome symbol rendering mode (.template does not exist on SymbolRenderingMode in the macOS 26 SDK)
2026-03-12 16:00 | — | Project licensed under CC0 1.0 Universal (public domain dedication)
2026-03-12 16:15 | SPECIFICATION.md, IMPLEMENTATION_PLAN.md, TEST_PLAN.md | Add local UNUserNotification on warning state transitions (OK→Warning and Warning→OK); permission denial handled gracefully; no notification on initial poll; removed "local notifications" from Out of Scope
<!-- LOG_END -->
