# Warning Lights — Test Plan

## Unit Tests

### MemoryMonitor
- Reports pressure level from dispatch source (`.normal`, `.warning`, `.critical`)
- Returns used/total bytes from `host_statistics64` with valid values
- Warning flag is `true` when pressure level is `.warning` or `.critical`
- Warning flag is `false` when pressure level is `.normal`
- Display stats report non-zero active, wired, and total bytes

### DiskMonitor
- Returns used bytes ≤ total bytes
- Returns a percentage in range [0, 100]
- Warning flag is `true` when usage > 90%
- Warning flag is `false` when usage ≤ 90%
- Correctly identifies boot volume

### CPUMonitor / CPUUsageSampler
- First sample returns `nil` (needs two samples for delta)
- Subsequent samples return a value in range [0.0, 1.0]
- Rolling window (capacity 10) does not trigger warning until full (10 samples collected)
- Sustained warning is `true` when all 10 samples exceed 75%
- Sustained warning resets to `false` when any sample drops below 75%
- `vm_deallocate` is called on the `processor_info_array_t` after each sample (no memory leak)

### SystemStatus
- `anyWarning` is `false` when all three monitors report no warnings
- `anyWarning` is `true` when memory warning is active
- `anyWarning` is `true` when disk warning is active
- `anyWarning` is `true` when CPU warning is active

### Icon Selection Logic
- Returns "all clear" SF Symbol when `anyWarning` is `false`
- Returns warning SF Symbol when any warning is `true`
- Multiple warnings → general warning symbol (not metric-specific)
- Single metric warning → appropriate metric-specific symbol

### Menu Construction
- Menu contains exactly 3 metric items + 1 separator + 1 About item + 1 Quit item
- All metric items are disabled (not selectable)
- Memory item text includes pressure level and used/total GB
- Disk item text includes current percentage
- CPU item text includes current usage and sustained-warning state
- About item is enabled and opens the standard macOS About panel when clicked
- Quit item is enabled and terminates the app when clicked

## Integration Tests

- App launches without a window appearing
- App does not appear in the Dock
- App does not appear in Command-Tab switcher
- Menu bar icon appears within 5 seconds of launch
- Icon updates within 70 seconds of a metric changing state

## Manual Tests

### App Lifecycle
- [ ] Launch app → menu bar icon appears, no window opens
- [ ] App not visible in Dock after launch
- [ ] App not visible in Command-Tab switcher
- [ ] Click Quit → app terminates, icon disappears from menu bar

### Menu Display
- [ ] Click menu bar icon → menu appears with 3 metric items + separator + About + Quit
- [ ] All metric items are grayed out (not selectable)
- [ ] Metric values are human-readable (not raw numbers)

### All Clear State
- [ ] On a healthy system, icon is the "all clear" symbol
- [ ] Menu shows normal readings for all metrics

### Memory Warning
- [ ] Simulate high memory pressure → icon changes to warning symbol
- [ ] Memory item in menu reflects high pressure state
- [ ] When pressure returns to normal → icon reverts to all-clear

### Disk Warning
- [ ] On a system with > 90% disk usage → icon shows warning
- [ ] Disk item in menu shows percentage > 90%

### CPU Warning
- [ ] Run CPU-intensive workload exceeding 75% of all-core capacity for > 10 minutes → icon shows warning
- [ ] CPU item in menu shows sustained overload state

### Appearance
- [ ] Icon renders correctly in light mode (dark menu bar text)
- [ ] Icon renders correctly in dark mode (light menu bar text)
- [ ] Icon renders correctly on colored menu bar backgrounds

### Login Item & Lifecycle
- [ ] Add app to Login Items (System Settings → General → Login Items); log out and back in → app starts silently, no UI shown, menu bar icon appears
- [ ] App not visible in Dock after login-item launch
- [ ] With app running, launch a second instance (double-click bundle) → second instance quits without any UI or error dialog
- [ ] Put system to sleep; wake → menu bar icon still present, monitoring continues
- [ ] First poll after wake reflects current (post-wake) system state, not stale pre-sleep values
- [ ] Log out while app is running → app terminates cleanly without blocking logout

## Edge Cases

- System has extremely low memory at launch
- Boot volume has less than 1 GB free
- App is quit and relaunched repeatedly
- System sleep/wake: monitoring resumes correctly after wake
- App launched at login before user-space is fully initialized: metric collection must handle transient errors gracefully

## Performance Tests

- Memory footprint of app should be < 20 MB RSS at idle
- CPU usage of the app itself should be < 0.5% between poll intervals
- Metric collection completes within 5 seconds on an idle system
