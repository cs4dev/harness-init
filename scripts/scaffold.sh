#!/usr/bin/env bash
# Deterministic half of the scaffold: copies the VERBATIM assets and the fixed doc
# templates into a target repo in one shot, so the model only writes the files that
# need judgment (SPEC, RULES, validate.sh, context.md, dev-map, skills SOPs, CI).
#
# Usage: scaffold.sh <target-dir> <project-name>
# Never clobbers: an existing file is skipped and reported (merge it by hand).
set -uo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <target-dir> <project-name>" >&2; exit 2; }
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
A="$SKILL/assets"
T="$1"; NAME="$2"
[ -d "$T" ] || { echo "target '$T' is not a directory" >&2; exit 2; }

fail=0
put() {  # put <src> <dest-rel> [exec] — copy, filling {{PROJECT_NAME}}
  local dest="$T/$2"
  if [ -e "$dest" ]; then printf '  - skip   %s (exists)\n' "$2"; return; fi
  mkdir -p "$(dirname "$dest")"
  local c; c="$(cat "$1")" || { printf '  ✗ read   %s\n' "$1"; fail=1; return; }
  printf '%s\n' "${c//'{{PROJECT_NAME}}'/$NAME}" > "$dest" || { printf '  ✗ write  %s\n' "$2"; fail=1; return; }
  [ "${3:-}" = exec ] && chmod +x "$dest"
  printf '  ✓ wrote  %s\n' "$2"
}

printf '=== Verbatim assets ===\n'
put "$A/workflow.yaml" harness/workflow/workflow.yaml
for r in "$A"/roles/*.md; do put "$r" "harness/workflow/roles/$(basename "$r")"; done
put "$A/validate-workflow.sh" harness/validate-workflow.sh exec

printf '\n=== Fixed doc templates ===\n'
put "$A/templates/docs/task-board.md" docs/task-board.md
put "$A/templates/docs/resume.md" harness/skills/resume.md
mkdir -p "$T/docs/tasks" && printf '  ✓ dir    docs/tasks/\n'

printf '\n=== Version stamp ===\n'
stamp="$T/harness/workflow/.harness-version"
if ! head=$(git -C "$SKILL" rev-parse HEAD 2>/dev/null); then
  printf '  - skip   skill dir is not a git checkout (upgrade will use 2-way diff)\n'
elif [ -n "$(git -C "$SKILL" status --porcelain assets)" ]; then
  printf '  - skip   skill assets/ dirty — HEAD would not match what was copied\n'
else
  printf '%s\n' "$head" > "$stamp" && printf '  ✓ stamp  %s\n' "$head"
fi

printf '\n=== Workflow sync ===\n'
if bash "$T/harness/validate-workflow.sh" >/dev/null 2>&1; then printf '  ✓ validate-workflow.sh passes\n'
else printf '  ✗ validate-workflow.sh fails — run it for details\n'; fail=1; fi

[ "$fail" -eq 0 ] && { printf '\nSCAFFOLD: OK\n'; exit 0; } || { printf '\nSCAFFOLD: FAIL\n'; exit 1; }
