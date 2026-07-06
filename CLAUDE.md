# Claude Fleet

Native macOS menubar app for supervising 20+ Claude Code sessions across iTerm2 windows.

> **Status:** the Swift app exists in this repo; the backing daemon it was designed to talk to was **never deployed** (`~/.claude-fleet/` and the launchd plist do not exist). Without the daemon the app has no data source. The full daemon plan is archived at `docs/archive/fleet-daemon-plan.md`.

## Design System
**Read `STYLEGUIDE.md` before any UI work.** Design tokens (colors, glass card values) live there.

## Stack
- Swift 5.9 / SwiftUI + AppKit
- macOS 14.0+
- Build tool: xcodegen → `.xcodeproj` → Xcode

## Dev Commands
```bash
cd ~/projects/claude-fleet
xcodegen generate          # regenerate .xcodeproj from project.yml
open ClaudeFleet.xcodeproj # open in Xcode, then ⌘B to build
```

Daemon control commands (launchctl, `fleet.py`) referenced in older docs belong to the never-deployed daemon — see `docs/archive/fleet-daemon-plan.md`.

## Architecture — what's actually on disk

The repo contains only the Swift app (`ClaudeFleet/`) plus `project.yml` for xcodegen.

```
ClaudeFleet.app
    ClaudeFleetApp.swift / AppDelegate.swift (NSStatusBar + NSPanel + key monitor)
        └── MainWindowView
                ├── TopBarView          (logo, mode, global role, scan button)
                ├── SessionsGridView → SessionCardView × N (role badge, approve/deny)
                ├── DetailSidebarView   (selected session detail)
                ├── StatusBarView
                └── Sheets/overlays: ConfigView, RolePickerView, ToastView,
                    AgentFocusView, HUDElements
```

`FleetBridge` (FSEvents watcher) and `FleetSocket` (Unix socket client) expect a daemon writing `~/.claude-fleet/state.json` and listening on `~/.claude-fleet/fleet.sock`. That daemon was never built — see `docs/archive/fleet-daemon-plan.md` for the intended design (including the roles system and its CLI).

## Key Files
| File | Purpose |
|------|---------|
| `project.yml` | xcodegen project definition |
| `ClaudeFleet/AppDelegate.swift` | NSStatusBar, NSPanel, keyboard shortcuts (Enter/Backspace/Cmd+Enter) |
| `ClaudeFleet/Models/FleetModels.swift` | FleetSession, FleetState, FleetMode, FleetRole |
| `ClaudeFleet/ViewModels/FleetViewModel.swift` | All @Published state, role methods, notifications |
| `ClaudeFleet/ViewModels/ConfigViewModel.swift` | Config sheet state |
| `ClaudeFleet/Services/FleetBridge.swift` | FSEvents watcher + state.json reader (read-only; no daemon writes it) |
| `ClaudeFleet/Services/FleetSocket.swift` | Unix socket client — approve/deny/scan/setRole commands (no daemon listens) |
| `ClaudeFleet/Views/RolePickerView.swift` | Per-session role picker sheet |

## Keyboard Shortcuts
- `Enter` — approve selected session
- `Backspace` — deny selected session
- `Cmd+Enter` — approve all safe sessions
- `⇧⌥Space` — toggle panel from anywhere

## Environment Variables
None — `FleetBridge`/`FleetSocket` hardcode `~/.claude-fleet/` paths (directory does not exist; daemon never deployed).

## Active Integrations
- FSEvents (file system watcher, in FleetBridge)
- UserNotifications (OS alerts on new paused sessions)

Daemon-side integrations (iTerm2 Python API, Claude CLI, launchd) were part of the never-deployed plan — see `docs/archive/fleet-daemon-plan.md`.
