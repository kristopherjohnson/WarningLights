# Warning Lights — Implementation Plan

## Phase 1: Project Setup

- [x] 1.1 Create Xcode project for macOS app, targeting macOS 26, with no main window [agent: swift-expert]
- [x] 1.2 Configure Info.plist: set `LSUIElement = YES`, set bundle identifier, app name [agent: swift-expert] [depends: 1.1]
- [x] 1.3 Remove default window/scene boilerplate; configure app delegate or `@main` entry point for menu-bar-only operation [agent: swift-expert] [depends: 1.2]

## Phase 2: System Monitoring [agent: swift-expert]

- [x] 2.1 Implement `MemoryMonitor`: use `DispatchSource.makeMemoryPressureSource(eventMask: .all)` for pressure level detection (`.normal`/`.warning`/`.critical`); use `host_statistics64` with `HOST_VM_INFO64` to read raw page counts for display stats (active, wired, compressed, free); report pressure level and used/total bytes [parallel]
- [x] 2.2 Implement `DiskMonitor`: check boot volume usage via `FileManager` or `statvfs`; report used/total bytes and percentage [parallel]
- [x] 2.3 Implement `CPUMonitor`: use `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO` to read per-core tick counts; compute delta between samples to get 0–100% normalized usage; maintain a `CPUUsageSampler` struct for tick state and a ring buffer of 10 samples for rolling window; `vm_deallocate` the returned array after each sample; warning triggers when all 10 samples exceed 75% [parallel]
- [x] 2.4 Create `SystemStatus` value type aggregating results from all three monitors [depends: 2.1, 2.2, 2.3]
- [x] 2.5 Create `SystemMonitor` actor that: (a) starts the memory pressure dispatch source, (b) runs a 60-second timer for disk and CPU polling plus memory display stats refresh, (c) publishes `SystemStatus` updates on change or timer tick [depends: 2.4]

## Phase 3: Menu Bar UI [agent: swift-expert]

- [x] 3.1 Create SwiftUI `MenuBarExtra` with SF Symbol icon driven by `SystemStatus` [depends: 1.3, 2.4]
- [x] 3.2 Implement icon selection logic: choose SF Symbol based on `SystemStatus` warning flags [depends: 2.4, 3.1]
- [x] 3.3 Build menu content using SwiftUI views: one disabled text item per metric showing latest measurement, Divider, About item (app name + version), Quit button [depends: 2.4, 3.1]
- [x] 3.4 Wire `SystemMonitor` updates to `MenuBarExtra` via `@Observable` or `@ObservableObject` [depends: 2.5, 3.2, 3.3]

## Phase 4: Login Item & Lifecycle [agent: swift-expert]

- [x] 4.1 Implement single-instance enforcement: at launch, check if another instance is already running (e.g., via `NSRunningApplication` or a named `NSDistributedNotificationCenter` ping); if so, quit the new instance silently [depends: 1.3]
- [x] 4.2 Handle system logout/restart/shutdown: observe `NSWorkspace.willPowerOffNotification` and `NSApplication.willTerminateNotification` to stop monitoring cleanly [depends: 2.5]
- [x] 4.3 Handle sleep/wake: observe `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification`; suspend polling timer on sleep and restart it on wake [depends: 2.5]
- [x] 4.4 Perform initial metric poll at launch (don't wait 60 seconds for first reading) [depends: 3.4]

## Phase 5: Integration & Polish [agent: swift-expert]

- [ ] 5.1 Verify icon renders correctly in light mode, dark mode, and with colored menu bar backgrounds [depends: 3.2]
- [ ] 5.2 Verify menu items display accurate, human-readable metric values [depends: 3.3]
- [ ] 5.3 Verify Quit menu item terminates the app cleanly [depends: 3.3]
- [ ] 5.4 Test on macOS 26 (simulator or device) [depends: 4.4, 5.1, 5.2, 5.3]

## Phase 6: Testing & Validation [agent: swift-expert]

- [ ] 6.1 Write unit tests for `MemoryMonitor`, `DiskMonitor`, `CPUMonitor` with mock data [parallel]
- [ ] 6.2 Write unit tests for `SystemStatus` warning flag logic [parallel]
- [ ] 6.3 Write unit tests for icon selection logic [parallel]
- [ ] 6.4 Manual test: simulate high memory pressure and verify icon changes [depends: 6.1, 6.2, 6.3]
- [ ] 6.5 Manual test: fill disk to > 90% and verify icon changes [depends: 6.4]
- [ ] 6.6 Manual test: add app to Login Items; log out and back in; verify app starts silently and icon appears [depends: 5.4]
- [ ] 6.7 Manual test: launch a second instance while app is running; verify second instance quits without UI [depends: 4.1]
- [ ] 6.8 Manual test: put system to sleep and wake it; verify monitoring resumes and icon reflects current state [depends: 4.3]

## Dependencies

- Xcode (latest, supporting macOS 26 SDK)
- No third-party packages

## Milestones

| Milestone | Tasks | Description |
|-----------|-------|-------------|
| M1: Skeleton | 1.1–1.3 | Compilable menu-bar-only app |
| M2: Monitoring | 2.1–2.5 | All three metrics collected |
| M3: UI | 3.1–3.4 | Icon and menu fully functional |
| M4: Login Item | 4.1–4.4 | Single-instance, sleep/wake, shutdown handling |
| M5: Shippable | 5.1–5.4 | Polished and manually tested |
| M6: Tested | 6.1–6.8 | Unit and manual tests passing |
