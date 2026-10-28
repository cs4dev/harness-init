#!/usr/bin/env bash
# PreToolUse hook for artifact-only roles (workflow.yaml artifact_only_roles):
# a file-writing tool may target docs/tasks/ only. Exit 2 blocks the call and
# hands stderr back to the agent. Installed via .claude/agents/<role>.md
# (harness/sync-agents.sh). Bash is not covered — QA must run the gate — so this
# stops the casual "I'll just fix it" edit, not a determined one; review catches the rest.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
input=$(cat)

# No jq dependency: pull the first file_path / notebook_path string out of the JSON.
path=$(printf '%s' "$input" | tr '\n' ' ' | grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"$/\1/')
[ -n "$path" ] || { echo "guard: no file path in tool input — blocked" >&2; exit 2; }

case "$path" in /*) ;; *) path="$root/$path" ;; esac
case "/$path/" in */../*|*/./*) echo "guard: '$path' — relative segments not allowed" >&2; exit 2 ;; esac
case "$path" in
  "$root"/docs/tasks/*) exit 0 ;;
  *) echo "guard: this role may write only under docs/tasks/ (tried: $path). Report the problem in your artifact; the developer owns code changes." >&2; exit 2 ;;
esac
