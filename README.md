# Warning Lights

A macOS menu bar app that monitors system health (memory pressure, disk usage, CPU load) and shows a warning icon when any metric is in a degraded state.

- Runs silently in the background with no dock icon and no windows
- Displays an SF Symbol in the menu bar: checkmark when healthy, orange warning triangle when something needs attention
- Hover over the icon to see a tooltip with current metrics
- Click the icon to see current readings for all metrics

## Requirements

- macOS 26 (Tahoe) or newer
- Xcode with the macOS 26 SDK

## Build

Open the project in Xcode:

```sh
open WarningLights.xcodeproj
```

Or build from the command line:

```sh
make build
```

## Run

```sh
make run
```

Or run directly from Xcode with **Product > Run** (Cmd+R).

The menu bar icon appears immediately. Click it to see memory, disk, CPU, and battery status.

## Install

```sh
make install
```

This builds the app and copies it to `/Applications`.

To uninstall:

```sh
make uninstall
```

### Launch at Login

To start Warning Lights automatically when you log in:

1. Open **System Settings > General > Login Items**
2. Click **+** under "Open at Login"
3. Select **Warning Lights** from `/Applications`

## Tests

```sh
make test
```

## Monitored Metrics

| Metric | Warning Condition | Polling |
|--------|-------------------|---------|
| Memory | System memory pressure reaches `.critical` | Event-driven via `DispatchSource`, refreshed every 60s |
| Disk | Boot volume usage > 90% | Every 60 seconds |
| CPU | Sustained usage > 75% for 10+ consecutive minutes | Every 60 seconds |
| Battery | On battery power with < 20% charge remaining | Event-driven via `IOPSNotificationCreateRunLoopSource`, refreshed every 60s |

Desktop Macs without a battery report no battery in the menu and never trigger a battery warning.

## License

This project is dedicated to the public domain under the [CC0 1.0 Universal](LICENSE) license.
