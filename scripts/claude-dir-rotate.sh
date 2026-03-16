#!/usr/bin/env bash
# claude-dir-rotate.sh — Enforce rotation rule on ~/.claude/ directory
# Rule: Rotate by size (10 MB) or time, never silently discard
#
# Phases:
#   1. Time-based cleanup: debug/file-history/snapshots (1 day), ephemeral (3 days), session data (7 days)
#   2. Empty file cleanup: 2-byte todo files, empty dirs
#   3. history.jsonl truncation: if over 10 MB, keep last 1000 lines
#   4. Hard cap: if ~/.claude/ still exceeds 500 MB, delete oldest session JSONLs
#   5. Summary log: JSONL audit entry with totals
#
# Protected (NEVER touched):
#   settings.json, settings.local.json, .credentials.json
#   CLAUDE.md symlink, SKILLS.md, DIRECTORY.md, CROSS_PROJECT.md
#   skills/, plugins/, cache/, commands/
#   Any */memory/* path (institutional knowledge)

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
LOG_FILE="${LOG_DIR}/claude-dir-rotate.jsonl"
DRY_RUN=false
MAX_AGE_DAYS=7          # Session data (project JSONLs, UUID dirs)
SHORT_AGE_DAYS=1        # High-churn dirs (debug, file-history, shell-snapshots)
MID_AGE_DAYS=3          # Ephemeral (todos, plans, tasks, backups, paste-cache)
HARD_CAP_MB=500
HISTORY_MAX_MB=10
HISTORY_KEEP_LINES=1000
MAX_BACKUPS=5

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No files will be deleted."
fi

if [[ ! -d "${CLAUDE_DIR}" ]]; then
    echo "ERROR: ${CLAUDE_DIR} does not exist" >&2
    exit 1
fi

mkdir -p "${LOG_DIR}"

# Track bytes reclaimed
BYTES_RECLAIMED=0

size_before=$(du -sb "${CLAUDE_DIR}" | awk '{print $1}')

# Helper: delete a file and track bytes reclaimed
delete_file() {
    local file="$1"
    local size
    size=$(stat -c%s "${file}" 2>/dev/null || echo 0)

    if ${DRY_RUN}; then
        echo "[DRY RUN] Would delete: ${file} (${size} bytes)"
    else
        rm -f "${file}"
        BYTES_RECLAIMED=$((BYTES_RECLAIMED + size))
    fi
}

# ─── Phase 1: Tiered time-based cleanup ───────────────────────────────

echo "=== Phase 1a: High-churn dirs (${SHORT_AGE_DAYS}-day TTL) ==="

# Debug logs — accumulate fast, rarely referenced after session
while IFS= read -r -d '' file; do
    delete_file "${file}"
done < <(find "${CLAUDE_DIR}/debug" -type f -mtime +${SHORT_AGE_DAYS} -print0 2>/dev/null)

# File-history session dirs
while IFS= read -r -d '' dir; do
    if ${DRY_RUN}; then
        local_size=$(du -sb "${dir}" | awk '{print $1}')
        echo "[DRY RUN] Would delete dir: ${dir} (${local_size} bytes)"
    else
        local_size=$(du -sb "${dir}" | awk '{print $1}')
        rm -rf "${dir}"
        BYTES_RECLAIMED=$((BYTES_RECLAIMED + local_size))
    fi
done < <(find "${CLAUDE_DIR}/file-history" -mindepth 1 -maxdepth 1 -type d -mtime +${SHORT_AGE_DAYS} -print0 2>/dev/null)

# Shell snapshots
while IFS= read -r -d '' file; do
    delete_file "${file}"
done < <(find "${CLAUDE_DIR}/shell-snapshots" -type f -mtime +${SHORT_AGE_DAYS} -print0 2>/dev/null)

echo "=== Phase 1b: Ephemeral dirs (${MID_AGE_DAYS}-day TTL) ==="

# Todos, plans, tasks, paste-cache, session-env
for ephemeral_dir in todos plans tasks paste-cache session-env; do
    if [[ -d "${CLAUDE_DIR}/${ephemeral_dir}" ]]; then
        while IFS= read -r -d '' file; do
            delete_file "${file}"
        done < <(find "${CLAUDE_DIR}/${ephemeral_dir}" -type f -mtime +${MID_AGE_DAYS} -print0 2>/dev/null)
    fi
done

# Task subdirectories (contain JSON files in UUID dirs)
if [[ -d "${CLAUDE_DIR}/tasks" ]]; then
    while IFS= read -r -d '' dir; do
        if ${DRY_RUN}; then
            local_size=$(du -sb "${dir}" | awk '{print $1}')
            echo "[DRY RUN] Would delete dir: ${dir} (${local_size} bytes)"
        else
            local_size=$(du -sb "${dir}" | awk '{print $1}')
            rm -rf "${dir}"
            BYTES_RECLAIMED=$((BYTES_RECLAIMED + local_size))
        fi
    done < <(find "${CLAUDE_DIR}/tasks" -mindepth 1 -maxdepth 1 -type d -mtime +${MID_AGE_DAYS} -print0 2>/dev/null)
fi

echo "=== Phase 1c: Session data (${MAX_AGE_DAYS}-day TTL) ==="

# Session JSONL files under projects/ (NOT memory/ dirs)
while IFS= read -r -d '' file; do
    delete_file "${file}"
done < <(find "${CLAUDE_DIR}/projects" -name '*.jsonl' -mtime +${MAX_AGE_DAYS} -not -path '*/memory/*' -print0 2>/dev/null)

# Session UUID directories under projects/ (subagent data, NOT memory/)
while IFS= read -r -d '' dir; do
    dirname=$(basename "${dir}")
    if [[ "${dirname}" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        if ${DRY_RUN}; then
            local_size=$(du -sb "${dir}" | awk '{print $1}')
            echo "[DRY RUN] Would delete dir: ${dir} (${local_size} bytes)"
        else
            local_size=$(du -sb "${dir}" | awk '{print $1}')
            rm -rf "${dir}"
            BYTES_RECLAIMED=$((BYTES_RECLAIMED + local_size))
        fi
    fi
done < <(find "${CLAUDE_DIR}/projects" -mindepth 2 -maxdepth 2 -type d -not -name 'memory' -mtime +${MAX_AGE_DAYS} -print0 2>/dev/null)

# Telemetry files
while IFS= read -r -d '' file; do
    delete_file "${file}"
done < <(find "${CLAUDE_DIR}/telemetry" -type f -mtime +${MAX_AGE_DAYS} -print0 2>/dev/null)

# ─── Phase 2: Empty file & backup cleanup ─────────────────────────────

echo "=== Phase 2: Empty file & backup cleanup ==="

# Remove 2-byte empty todo files (just "[]")
count=0
while IFS= read -r -d '' file; do
    delete_file "${file}"
    count=$((count + 1))
done < <(find "${CLAUDE_DIR}/todos" -type f -size 2c -print0 2>/dev/null)
[[ $count -gt 0 ]] && echo "Removed ${count} empty todo files"

# Keep only N most recent backups
if [[ -d "${CLAUDE_DIR}/backups" ]]; then
    backup_count=$(find "${CLAUDE_DIR}/backups" -type f | wc -l)
    if [[ ${backup_count} -gt ${MAX_BACKUPS} ]]; then
        find "${CLAUDE_DIR}/backups" -type f -printf '%T@ %p\n' | sort -n | head -n $((backup_count - MAX_BACKUPS)) | cut -d' ' -f2- | while read -r old_backup; do
            delete_file "${old_backup}"
        done
        echo "Trimmed backups to ${MAX_BACKUPS} most recent"
    fi
fi

# Clean up empty directories (exclude protected top-level dirs)
find "${CLAUDE_DIR}" -mindepth 2 -type d -empty \
    -not -path '*/memory*' \
    -not -path '*/skills/*' \
    -not -path '*/plugins/*' \
    -not -path '*/cache/*' \
    -not -path '*/commands/*' \
    -delete 2>/dev/null || true

echo "Phase 2 complete."

# ─── Phase 3: history.jsonl truncation ──────────────────────────────────

echo "=== Phase 3: history.jsonl truncation ==="

HISTORY_FILE="${CLAUDE_DIR}/history.jsonl"
if [[ -f "${HISTORY_FILE}" ]]; then
    history_size=$(stat -c%s "${HISTORY_FILE}")
    history_max_bytes=$((HISTORY_MAX_MB * 1024 * 1024))

    if [[ ${history_size} -gt ${history_max_bytes} ]]; then
        if ${DRY_RUN}; then
            echo "[DRY RUN] Would truncate history.jsonl from ${history_size} bytes to last ${HISTORY_KEEP_LINES} lines"
        else
            tmp_file=$(mktemp "${HISTORY_FILE}.XXXXXX")
            tail -n ${HISTORY_KEEP_LINES} "${HISTORY_FILE}" > "${tmp_file}"
            new_size=$(stat -c%s "${tmp_file}")
            mv "${tmp_file}" "${HISTORY_FILE}"
            BYTES_RECLAIMED=$((BYTES_RECLAIMED + history_size - new_size))
            echo "Truncated history.jsonl: ${history_size} -> ${new_size} bytes"
        fi
    else
        echo "history.jsonl is ${history_size} bytes (under ${HISTORY_MAX_MB} MB limit), skipping."
    fi
else
    echo "No history.jsonl found, skipping."
fi

# ─── Phase 4: Hard cap (500 MB) ────────────────────────────────────────

echo "=== Phase 4: Hard cap check (${HARD_CAP_MB} MB) ==="

current_size_kb=$(du -sk "${CLAUDE_DIR}" | awk '{print $1}')
hard_cap_kb=$((HARD_CAP_MB * 1024))

if [[ ${current_size_kb} -gt ${hard_cap_kb} ]]; then
    echo "Directory is ${current_size_kb} KB (over ${HARD_CAP_MB} MB cap). Deleting oldest session JSONLs..."

    # Build list of session JSONLs sorted oldest-first (exclude memory/)
    while IFS= read -r -d '' file; do
        echo "${file}"
    done < <(find "${CLAUDE_DIR}/projects" -name '*.jsonl' -not -path '*/memory/*' -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | tac) | while read -r oldest_file; do

        current_size_kb=$(du -sk "${CLAUDE_DIR}" | awk '{print $1}')
        if [[ ${current_size_kb} -le ${hard_cap_kb} ]]; then
            break
        fi

        delete_file "${oldest_file}"
    done

    current_size_kb=$(du -sk "${CLAUDE_DIR}" | awk '{print $1}')
    echo "After hard cap enforcement: ${current_size_kb} KB"
else
    echo "Directory is ${current_size_kb} KB (under ${HARD_CAP_MB} MB cap), no action needed."
fi

# ─── Phase 5: Summary log ──────────────────────────────────────────────

size_after=$(du -sb "${CLAUDE_DIR}" | awk '{print $1}')

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
log_entry=$(printf '{"timestamp":"%s","dry_run":%s,"bytes_reclaimed":%d,"size_before":%d,"size_after":%d}' \
    "${timestamp}" "${DRY_RUN}" "${BYTES_RECLAIMED}" "${size_before}" "${size_after}")

if ${DRY_RUN}; then
    echo "=== Summary (DRY RUN) ==="
    echo "${log_entry}"
else
    echo "${log_entry}" >> "${LOG_FILE}"
    echo "=== Summary ==="
    echo "Reclaimed: $((BYTES_RECLAIMED / 1024)) KB"
    echo "Size before: $((size_before / 1024)) KB"
    echo "Size after: $((size_after / 1024)) KB"
    echo "Log written to: ${LOG_FILE}"
fi
