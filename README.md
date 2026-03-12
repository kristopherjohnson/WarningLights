# Warning Lights

A macOS menu bar app that monitors system health (memory pressure, disk usage, CPU load) and shows a warning icon when any metric is in a degraded state.

- Runs silently in the background with no dock icon and no windows
- Displays an SF Symbol in the menu bar: checkmark when healthy, warning triangle when something needs attention
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
xcodebuild -project WarningLights.xcodeproj -scheme WarningLights -configuration Release build
```

The built app bundle lands in the Xcode derived data directory. To place it somewhere specific:

```sh
xcodebuild -project WarningLights.xcodeproj -scheme WarningLights -configuration Release \
    CONFIGURATION_BUILD_DIR="$PWD/build" build
```

## Run

After building, launch the app:

```sh
open build/WarningLights.app
```

Or run directly from Xcode with **Product > Run** (Cmd+R).

The menu bar icon appears immediately. Click it to see memory, disk, and CPU status.

## Install

Copy the built app to `/Applications`:

```sh
cp -R build/WarningLights.app /Applications/
```

### Launch at Login

To start Warning Lights automatically when you log in:

1. Open **System Settings > General > Login Items**
2. Click **+** under "Open at Login"
3. Select **Warning Lights** from `/Applications`

## Tests

```sh
xcodebuild -project WarningLights.xcodeproj -scheme WarningLights test
```

## Monitored Metrics

| Metric | Warning Condition | Polling |
|--------|-------------------|---------|
| Memory | System memory pressure reaches `.warning` or `.critical` | Event-driven via `DispatchSource`, refreshed every 60s |
| Disk | Boot volume usage > 90% | Every 60 seconds |
| CPU | Sustained usage > 75% for 10+ consecutive minutes | Every 60 seconds |

## License

Copyright Kris Johnson. All rights reserved.
