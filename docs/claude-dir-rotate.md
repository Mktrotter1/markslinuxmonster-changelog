# claude-dir-rotate — Daily ~/.claude/ Cleanup

## Overview

Automated daily cleanup of the Claude Code `~/.claude/` directory to prevent unbounded growth from session artifacts. Runs as a systemd user timer at 23:55 UTC.

## Problem

Claude Code accumulates ephemeral data across sessions:
- **Debug logs**: ~1 MB per session, 80+ files in days
- **File-history**: Per-session UUID dirs with file snapshots
- **Shell snapshots**: ~6 KB each, one per shell init
- **Todos/tasks**: 2-byte empty JSON files from every subagent
- **Plans**: Markdown plan files, 4-23 KB each
- **Backups**: .claude.json rotation files, ~54 KB each
- **Session JSONLs**: Full conversation transcripts under `projects/`

Left unchecked, `~/.claude/` grows to 150+ MB in under a week, slowing startup as the directory tree is enumerated.

## Architecture

```
~/.config/systemd/user/
├── claude-dir-rotate.timer    # Fires daily at 23:55 UTC
└── claude-dir-rotate.service  # Runs the cleanup script (oneshot)

~/repos/Mktrotter1/markslinuxmonster-changelog/
└── scripts/claude-dir-rotate.sh   # The actual cleanup logic
```

## Tiered TTL Strategy (Updated 2026-03-13)

| Tier | TTL | Directories | Rationale |
|------|-----|-------------|-----------|
| **High-churn** | 1 day | `debug/`, `file-history/`, `shell-snapshots/` | Regenerated every session, no value after day ends |
| **Ephemeral** | 3 days | `todos/`, `plans/`, `tasks/`, `paste-cache/`, `session-env/` | Occasionally referenced next day, stale after 3 |
| **Session data** | 7 days | `projects/**/*.jsonl`, UUID session dirs, `telemetry/` | May need for debugging recent sessions |

## 5-Phase Execution

1. **Phase 1a-1c**: Tiered time-based deletion (1/3/7 day TTLs)
2. **Phase 2**: Empty file cleanup (2-byte todo `[]` files) + backup rotation (keep 5 most recent)
3. **Phase 3**: `history.jsonl` truncation (if >10 MB, keep last 1000 lines)
4. **Phase 4**: Hard cap enforcement (if >500 MB, delete oldest session JSONLs)
5. **Phase 5**: JSONL audit log entry with bytes reclaimed

## Protected Paths (NEVER touched)

- `settings.json`, `settings.local.json`, `.credentials.json`
- `CLAUDE.md` symlink, `SKILLS.md`, `DIRECTORY.md`, `CROSS_PROJECT.md`
- `skills/` (symlinks to claude-skills repo)
- `plugins/` (marketplace-synced)
- `projects/*/memory/` (institutional knowledge)
- `cache/`, `commands/`

## Usage

```bash
# Dry run (see what would be deleted, no changes)
bash scripts/claude-dir-rotate.sh --dry-run

# Manual run
bash scripts/claude-dir-rotate.sh

# Check timer status
systemctl --user status claude-dir-rotate.timer

# View last run output
journalctl --user -u claude-dir-rotate.service --no-pager -n 30

# View audit log
tail -5 logs/claude-dir-rotate.jsonl
```

## Typical Results

| Metric | Before (daily) | After cleanup |
|--------|---------------|---------------|
| `debug/` | 20-40 MB | 2-5 MB |
| `file-history/` | 1-4 MB | <100 KB |
| `todos/` | 30-50 empty files | 0 |
| `shell-snapshots/` | 50-70 KB | 6-24 KB |
| Total `~/.claude/` | 130-160 MB | 80-100 MB |

## History

- **2026-03-13**: Upgraded from flat 7-day TTL to tiered 1/3/7 day strategy. Added Phase 2 (empty file cleanup, backup rotation). Timer changed from `OnCalendar=daily` (midnight + 5min jitter) to `23:55:00` sharp.
- **Initial**: 4-phase script with 7-day TTL on all ephemeral dirs, 500 MB hard cap, history.jsonl truncation.
