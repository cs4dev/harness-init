#!/usr/bin/env bash
# Workflow consistency gate (article Ch 7.6). Catches drift between the workflow
# definition and the role contracts before it silently corrupts the pipeline.
# Not a full "workflow compiler" — a lightweight sync check.
set -uo pipefail
cd "$(dirname "$0")/.."

WF="harness/workflow/workflow.yaml"
ROLES_DIR="harness/workflow/roles"
fail=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; fail=1; }

printf '=== Workflow consistency ===\n'

[ -f "$WF" ] && ok "workflow.yaml present" || { bad "missing $WF"; printf '\nWORKFLOW: FAIL\n'; exit 1; }

# Agents referenced by stages (lines like "    agent: developer").
agents=$(grep -E '^[[:space:]]*agent:[[:space:]]' "$WF" | sed -E 's/.*agent:[[:space:]]*//' | sort -u)

# 1. Every referenced agent has a contract with the mandatory sections.
for a in $agents; do
  f="$ROLES_DIR/$a.md"
  if [ ! -f "$f" ]; then
    bad "stage agent '$a' has no contract ($f)"
    continue
  fi
  missing=""
  grep -q '^## Reads' "$f"     || missing="$missing Reads"
  grep -q '^## Produces' "$f"  || missing="$missing Produces"
  grep -q 'Model tier' "$f"    || missing="$missing Model-tier"
  if [ -n "$missing" ]; then
    bad "contract $a.md missing sections:$missing"
  else
    ok "contract $a.md complete"
  fi
done

# 2. No orphan contracts (a role file no stage references).
for f in "$ROLES_DIR"/*.md; do
  base=$(basename "$f" .md)
  if ! echo "$agents" | grep -qx "$base"; then
    bad "orphan contract $base.md (no stage references it)"
  fi
done

# 3. Every track references only defined stage ids.
all_stage_ids=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]' "$WF" | sed -E 's/.*id:[[:space:]]*//' | sort -u)
track_lines=$(sed -n '/^tracks:/,/^[a-z]/p' "$WF" | grep -E '^[[:space:]]+[a-z]+:[[:space:]]*\[')
if [ -n "$track_lines" ]; then
  while IFS= read -r line; do
    tname=$(echo "$line" | sed -E 's/^[[:space:]]*([a-z]+):.*/\1/')
    tstages=$(echo "$line" | sed -E 's/.*\[(.*)\].*/\1/' | tr ',' '\n' | sed -E 's/[[:space:]]//g')
    tfail=0
    for s in $tstages; do
      echo "$all_stage_ids" | grep -qx "$s" || { bad "track '$tname' references undefined stage '$s'"; tfail=1; }
    done
    [ "$tfail" -eq 0 ] && ok "track '$tname' stages all defined"
  done <<EOF
$track_lines
EOF
else
  bad "no tracks defined (expected tracks: full/fast)"
fi

# 4. Every rollback target is a real stage id.
stage_ids=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]' "$WF" | sed -E 's/.*id:[[:space:]]*//' | sort -u)
rollback_targets=$(grep -E '^[[:space:]]*to:[[:space:]]' "$WF" | sed -E 's/.*to:[[:space:]]*//' | sort -u)
for t in $rollback_targets; do
  if echo "$stage_ids" | grep -qx "$t"; then
    ok "rollback target '$t' is a valid stage"
  else
    bad "rollback target '$t' is not a defined stage"
  fi
done

if [ "$fail" -eq 0 ]; then printf '\nWORKFLOW: PASS\n'; exit 0
else printf '\nWORKFLOW: FAIL\n'; exit 1; fi
