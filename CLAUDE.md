# Claude Fleet

Native macOS menubar app for supervising 20+ Claude Code sessions across iTerm2 windows.

## Stack
- Swift 5.9 / SwiftUI + AppKit
- macOS 14.0+
- Build tool: xcodegen → `.xcodeproj` → Xcode
- Python 3 (daemon, iTerm2 API)

## Dev Commands
```bash
cd ~/projects/claude-fleet
xcodegen generate          # regenerate .xcodeproj from project.yml
open ClaudeFleet.xcodeproj # open in Xcode, then ⌘B to build

# Daemon control
launchctl start com.wiking.claude-fleet   # start daemon
launchctl stop com.wiking.claude-fleet    # stop daemon
tail -f ~/.claude-fleet/daemon.log        # live daemon logs
python3 ~/.claude-fleet/fleet.py status  # current state
python3 ~/.claude-fleet/fleet.py set-role --global --role builder
```

## Architecture (v2)

```
launchd (auto-start on login)
    └── fleet_daemon.py (persistent async daemon)
            ├── iTerm2 API — polls every 3s, detects Claude pauses
            ├── claude CLI — analyzes with Haiku (Max sub, ~1-2s)
            ├── roles.json — per-session/project AI personalities
            ├── state.json — atomic writes (Swift reads via FSEvents)
            └── fleet.sock — Unix socket for Swift commands

ClaudeFleet.app
    AppDelegate (NSStatusBar + NSPanel + key monitor)
        └── MainWindowView
                ├── TopBarView     (logo, mode, global role, scan button)
                ├── SessionsGridView → SessionCardView × N (role badge, approve/deny)
                ├── DetailSidebarView (selected session detail)
                └── StatusBarView

State flow:
  daemon writes state.json → FSEvents → FleetBridge → FleetViewModel → SwiftUI
  user approve/deny → FleetSocket → fleet.sock → daemon → iTerm2 session
```

## Key Files
| File | Purpose |
|------|---------|
| `~/.claude-fleet/fleet_daemon.py` | Persistent async daemon — iTerm2 polling, analysis, socket server |
| `~/.claude-fleet/fleet.py` | Thin CLI wrapper — sends commands to daemon via socket |
| `~/.claude-fleet/roles.json` | Role config: global, per-project, per-session |
| `~/Library/LaunchAgents/com.wiking.claude-fleet.plist` | launchd auto-start |
| `ClaudeFleet/AppDelegate.swift` | NSStatusBar, NSPanel, keyboard shortcuts (Enter/Backspace/Cmd+Enter) |
| `ClaudeFleet/Models/FleetModels.swift` | FleetSession, FleetState, FleetMode, FleetRole |
| `ClaudeFleet/ViewModels/FleetViewModel.swift` | All @Published state, role methods, notifications |
| `ClaudeFleet/Services/FleetBridge.swift` | FSEvents watcher + state.json reader (read-only) |
| `ClaudeFleet/Services/FleetSocket.swift` | Unix socket client — approve/deny/scan/setRole commands |
| `ClaudeFleet/Views/RolePickerView.swift` | Per-session role picker sheet |

## Roles System
Six built-in roles control how Haiku analyzes each session:

| Role | Behavior | Auto-threshold |
|------|----------|---------------|
| `builder` | Keep implementing, approve most things | 0.70 |
| `yeoman` | Say yes to everything non-destructive | 0.50 |
| `cautious` | Conservative, surface more for review | 0.88 |
| `reviewer` | Flag completed work as QA | 0.80 |
| `shipper` | Aggressively approve build/deploy steps | 0.65 |
| `scout` | Never auto-respond, observe only | never |

Set via UI (role pill on session card) or CLI:
```bash
python3 ~/.claude-fleet/fleet.py set-role --global --role builder
python3 ~/.claude-fleet/fleet.py set-role --project myapp --role cautious
```

Custom roles: add to `~/.claude-fleet/roles.json` under `"custom"`.

## Keyboard Shortcuts
- `Enter` — approve selected session
- `Backspace` — deny selected session
- `Cmd+Enter` — approve all safe sessions
- `⇧⌥Space` — toggle panel from anywhere

## Design Tokens
- Background: `#070c1a` (midnight navy)
- Accent: `#00d4ff` (cyan)
- Risk: `#ff6040` (red-orange)
- Active: `#34d399` (green)
- Glass cards: `rgba(255,255,255,0.035)` bg, `rgba(255,255,255,0.07)` border

## Environment Variables
None — uses hardcoded `~/.claude-fleet/` paths

## Active Integrations
- iTerm2 Python API (`pip3 install iterm2`)
- Claude CLI (Max subscription, Haiku model)
- FSEvents (file system watcher)
- UserNotifications (OS alerts on new paused sessions)
- launchd (daemon auto-start)
