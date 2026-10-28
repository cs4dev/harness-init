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

# 5. Every `next:` target (scalar or [list]) is a real stage id.
next_targets=$(grep -E '^[[:space:]]*next:[[:space:]]' "$WF" | sed -E 's/.*next:[[:space:]]*//; s/#.*//; s/[][]//g' \
  | tr ',' '\n' | sed -E 's/[[:space:]]//g' | grep -v '^$' | sort -u)
for t in $next_targets; do
  echo "$stage_ids" | grep -qx "$t" && ok "next target '$t' is a valid stage" || bad "next target '$t' is not a defined stage"
done

# Stage blocks as "id agent produces" lines, for the per-stage checks below.
stage_rows=$(awk '
  function flush() { if (id != "") print id, (agent == "" ? "-" : agent), (prod == "" ? "-" : prod) }
  /^[[:space:]]*-[[:space:]]*id:[[:space:]]/ { flush(); id = $NF; agent = ""; prod = ""; next }
  /^[^[:space:]#]/ { flush(); id = "" }
  id != "" && /^[[:space:]]*agent:[[:space:]]/    { sub(/#.*/, ""); agent = $2 }
  id != "" && /^[[:space:]]*produces:[[:space:]]/ { sub(/#.*/, ""); prod = $2 }
  END { flush() }' "$WF")

# 6. Each stage's artifact is named in its agent's `## Produces` section.
while read -r sid sagent sprod; do
  [ -n "$sid" ] && [ "$sprod" != "-" ] && [ -f "$ROLES_DIR/$sagent.md" ] || continue
  if awk '/^## Produces/{f=1;next} /^## /{f=0} f' "$ROLES_DIR/$sagent.md" | grep -qF "$sprod"; then
    ok "stage '$sid': $sagent.md produces $sprod"
  else
    bad "stage '$sid' produces $sprod but $sagent.md's ## Produces never names it"
  fi
done <<EOF
$stage_rows
EOF

# 7. model_tiers ↔ tier_models ↔ each contract's `## Model tier` agree.
tier_names=$(sed -n '/^tier_models:/,/^[a-z]/p' "$WF" | grep -E '^[[:space:]]+[a-z]+:' | sed -E 's/^[[:space:]]*([a-z]+):.*/\1/')
# The loop runs in a pipeline subshell, so collect its lines and lift failures after.
tier_out=$(sed -n '/^model_tiers:/,/^[a-z]/p' "$WF" | grep -E '^[[:space:]]+[a-z-]+:' | sed -E 's/#.*//' |
while IFS=: read -r role tier; do
  role=$(echo "$role" | tr -d '[:space:]'); tier=$(echo "$tier" | tr -d '[:space:]')
  echo "$tier_names" | grep -qx "$tier" || { echo "  ✗ model_tiers.$role = '$tier' has no tier_models entry"; continue; }
  f="$ROLES_DIR/$role.md"
  [ -f "$f" ] || { echo "  ✗ model_tiers.$role has no contract ($f)"; continue; }
  # First word of the first non-blank line under "## Model tier", e.g. "Medium — …" → medium.
  ctier=$(awk '/^## Model tier/{f=1;next} /^## /{f=0} f && NF {print; exit}' "$f" \
    | sed -E 's/^[^A-Za-z]*([A-Za-z]+).*/\1/' | tr '[:upper:]' '[:lower:]')
  [ "$ctier" = "$tier" ] && echo "  ✓ tier $role = $tier (yaml ↔ contract)" \
    || echo "  ✗ tier drift: workflow.yaml says $role=$tier, $role.md says '${ctier:-none}'"
done)
[ -n "$tier_out" ] && printf '%s\n' "$tier_out"
case "$tier_out" in *✗*) fail=1 ;; esac
grep -q '^model_tiers:' "$WF" || bad "no model_tiers block"

# 8. Rendered sub-agents (.claude/agents/) match workflow.yaml.
if [ -f harness/sync-agents.sh ]; then
  bash harness/sync-agents.sh --check >/dev/null 2>&1 && ok "sub-agents in sync (.claude/agents)" \
    || bad "sub-agents stale or missing (run harness/sync-agents.sh)"
  [ -f harness/guard-artifact-write.sh ] && ok "write guard present" || bad "missing harness/guard-artifact-write.sh"
else
  bad "missing harness/sync-agents.sh"
fi

if [ "$fail" -eq 0 ]; then printf '\nWORKFLOW: PASS\n'; exit 0
else printf '\nWORKFLOW: FAIL\n'; exit 1; fi
