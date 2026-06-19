# Flux

**A macOS menu bar system observability app.**

Flux tracks real-time system activity, stores historical usage, and helps
explain what changed over time.

## Run locally

You need macOS 14 or newer and the Xcode Command Line Tools.

1. Install the command line tools (you only need to do this once):

   ```bash
   xcode-select --install
   ```

2. Clone Flux and open the project folder:

   ```bash
   git clone https://github.com/shlokrj/flux.git
   cd flux
   ```

3. Build and launch the app:

   ```bash
   ./scripts/run.sh
   ```

Look for the Flux gauge in the top-right of your menu bar.

## Tech stack

| Layer | Tools |
| --- | --- |
| App | Swift, SwiftUI, AppKit |
| Interface | MenuBarExtra, Swift Charts |
| System data | Mach and Darwin APIs, IOKit, NSWorkspace, libproc |
| Storage | SQLite |
| Build and packaging | Swift Package Manager, native macOS app bundle |
