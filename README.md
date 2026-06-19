# Flux

**A macOS menu bar system observability app.**

Flux tracks real-time system activity, stores historical usage, and helps
explain what changed over time. Think *Activity Monitor + Screen Time*, but
cleaner, historical, and developer-focused.

Flux answers two questions:

1. **"What is my Mac doing right now?"**
2. **"What has been using my Mac's resources over time?"**

> **Status:** early scaffold. The structure, models, and component stubs are in
> place; the system-metric integrations are being built out phase by phase (see
> [Roadmap](#roadmap)). Most values are placeholders for now.

## What makes Flux different

Most monitors show current stats. Flux focuses on:

- **History** — not just current CPU/RAM, but what happened over hours/days/weeks.
- **App usage** — Screen Time-style analytics for which apps you actually use.
- **Resource attribution** — which apps/processes caused a spike.
- **Developer awareness** — local servers, ports, Python/Node processes, project activity.
- **Timeline explanations** — *"CPU spiked because Python started training a model"*, not raw numbers.

## Features

- **Menu bar status** — compact live CPU / RAM in the menu bar; click for a quick overview.
- **Live dashboard** — cards for CPU, memory, storage, battery, network, uptime + live charts.
- **Process table** — top resource users, sortable by CPU / memory / longest running / newest.
- **App usage analytics** — foreground app time, daily/weekly breakdowns, coding-time estimates.
- **Historical tracking** — local SQLite history of snapshots and sessions.
- **Timeline** — derived events (CPU/RAM spikes, low battery, storage jumps, network spikes).

## Tech stack

- **Swift** + **SwiftUI** (`MenuBarExtra`)
- **Swift Charts** for live graphs
- **SQLite** for local history
- macOS **System** / **Process** APIs (host_statistics, sysctl, IOKit, NSWorkspace)

Optional later: a Python/FastAPI or Rust helper for deeper systems-level metrics.

## Project structure

```text
flux/
├── Package.swift
├── README.md
└── Sources/
    └── Flux/
        ├── FluxApp.swift           # @main App: MenuBarExtra + dashboard window
        ├── Views/
        │   ├── MenuBarView.swift   # dropdown panel
        │   └── DashboardView.swift # main window
        ├── Collectors/
        │   ├── MetricsCollector.swift   # CPU / memory / battery / network sampling
        │   ├── ProcessCollector.swift   # process enumeration + sorting
        │   └── AppUsageTracker.swift    # foreground-app sessions (NSWorkspace)
        ├── Storage/
        │   └── HistoryStore.swift  # SQLite-backed history + range queries
        ├── Engine/
        │   └── TimelineEngine.swift # event detection from the snapshot stream
        └── Models/
            ├── SystemSnapshot.swift
            ├── ProcessSnapshot.swift
            └── AppUsageSession.swift
```

## Building

```bash
# Compile the collectors / models / store / engine from the CLI:
swift build
```

The menu bar UI needs an app bundle, so the shipped product is built as a real
`.app` in Xcode (target with `LSUIElement = YES`). The SwiftUI views compile
under `swift build`, but use Xcode to run Flux as a menu bar app.

## Roadmap

| Phase | Focus |
| ----- | ----- |
| 1 | Native menu bar MVP — icon/text, dropdown, CPU, memory, battery, basic process list |
| 2 | Dashboard — main window, live charts, disk, network, top processes |
| 3 | History — SQLite storage of snapshots |
| 4 | App usage — foreground tracking, daily/weekly usage, coding-time estimate |
| 5 | Timeline — event detection (high CPU/RAM, low battery, storage jump, network spike) |
| 6 | Developer features — port/dev-server detection, Python/Node processes, project inference, git activity |
