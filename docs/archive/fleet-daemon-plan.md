# Fleet Daemon — Archived Plan (never deployed)

> **ARCHIVED 2026-07-06.** This daemon architecture was documented in CLAUDE.md as if live, but was **never deployed**: `~/.claude-fleet/` (fleet_daemon.py, fleet.py, roles.json, state.json, fleet.sock) and `~/Library/LaunchAgents/com.wiking.claude-fleet.plist` do not exist on disk. Moved here during the 2026-07-06 CLAUDE.md audit so agents don't execute a dead plan. The Swift app's daemon-facing code (`FleetBridge`, `FleetSocket`, `RolePickerView`) exists and targets this design. Related plan: `docs/superpowers/plans/2026-04-07-fleet-v2.md`.

Content below preserved verbatim from CLAUDE.md.

---

## Dev Commands (daemon)

```bash
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

State flow:
  daemon writes state.json → FSEvents → FleetBridge → FleetViewModel → SwiftUI
  user approve/deny → FleetSocket → fleet.sock → daemon → iTerm2 session
```

## Key Files (daemon side)

| File | Purpose |
|------|---------|
| `~/.claude-fleet/fleet_daemon.py` | Persistent async daemon — iTerm2 polling, analysis, socket server |
| `~/.claude-fleet/fleet.py` | Thin CLI wrapper — sends commands to daemon via socket |
| `~/.claude-fleet/roles.json` | Role config: global, per-project, per-session |
| `~/Library/LaunchAgents/com.wiking.claude-fleet.plist` | launchd auto-start |

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

## Daemon-side integrations (never installed)

- iTerm2 Python API (`pip3 install iterm2`)
- Claude CLI (Max subscription, Haiku model)
- launchd (daemon auto-start)
