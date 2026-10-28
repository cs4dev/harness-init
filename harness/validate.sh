#!/usr/bin/env bash
# Self-gate for the harness-init skill: the skill's own "done = this exits 0".
# Runs the deterministic machinery (scaffold.sh, validate-workflow.sh, the
# validate.sh template) against throwaway repos and asserts both the PASS and the
# FAIL paths — a gate that never fails proves nothing.
#
# Categories: A syntax · B scaffold behavior · C workflow gate · D validate.sh
# template · E docs ↔ files.  Same conventions as the gates it ships: set -uo
# pipefail without -e, [[:space:]] not \s, no GNU-only flags (CI runs Linux + macOS).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; fail=1; }
# expect <pass|fail> <label> <cmd…> — run quietly, assert the exit status.
expect() {
  local want=$1 label=$2; shift 2
  if "$@" >/dev/null 2>&1; then got=pass; else got=fail; fi
  [ "$got" = "$want" ] && ok "$label" || bad "$label (expected $want, got $got)"
}
# edit <file> <sed-expr> — portable in-place sed (BSD and GNU disagree on -i).
edit() { sed -E "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
# fresh <dir> [name] — a new scaffold to mutate.
fresh() { mkdir -p "$1" && bash scripts/scaffold.sh "$1" "${2:-demo}" >/dev/null 2>&1; }

printf '=== A. Syntax ===\n'
for f in scripts/*.sh assets/*.sh assets/templates/validate.sh.template harness/validate.sh; do
  expect pass "bash -n $f" bash -n "$f"
done

printf '\n=== B. scaffold.sh ===\n'
name='R&D \1 "Tool"'
expect pass "fresh scaffold exits 0" fresh "$TMP/b1" "$name"
for p in harness/workflow/workflow.yaml harness/validate-workflow.sh docs/task-board.md \
         harness/skills/resume.md docs/tasks; do
  [ -e "$TMP/b1/$p" ] && ok "wrote $p" || bad "missing $p"
done
[ -x "$TMP/b1/harness/validate-workflow.sh" ] && ok "validate-workflow.sh is executable" || bad "validate-workflow.sh not executable"
n_roles=$(ls "$TMP/b1/harness/workflow/roles" | wc -l | tr -d ' ')
[ "$n_roles" = "$(ls assets/roles | wc -l | tr -d ' ')" ] && ok "all $n_roles roles copied" || bad "roles copied: $n_roles"
grep -qF "# Task Board — $name" "$TMP/b1/docs/task-board.md" \
  && ok "project name substituted literally (& \\1 \")" || bad "project name mangled: $(head -1 "$TMP/b1/docs/task-board.md")"
grep -rq '{{PROJECT_NAME}}' "$TMP/b1" && bad "{{PROJECT_NAME}} left unfilled" || ok "no {{PROJECT_NAME}} left"
cmp -s assets/workflow.yaml "$TMP/b1/harness/workflow/workflow.yaml" && ok "workflow.yaml copied verbatim" || bad "workflow.yaml altered in copy"

echo keep-me > "$TMP/b1/harness/workflow/.harness-version"
echo local-edit > "$TMP/b1/docs/task-board.md"
expect pass "re-run on a scaffolded repo exits 0" bash scripts/scaffold.sh "$TMP/b1" demo
[ "$(cat "$TMP/b1/harness/workflow/.harness-version")" = keep-me ] && ok "existing stamp not clobbered" || bad "stamp clobbered"
[ "$(cat "$TMP/b1/docs/task-board.md")" = local-edit ] && ok "existing file not clobbered" || bad "task-board clobbered"

mkdir -p "$TMP/b2/harness/workflow" && echo 'version: 0' > "$TMP/b2/harness/workflow/workflow.yaml"
bash scripts/scaffold.sh "$TMP/b2" demo >/dev/null 2>&1
[ -e "$TMP/b2/harness/workflow/.harness-version" ] && bad "stamped over a kept verbatim asset" || ok "no stamp when a verbatim asset was kept"
expect fail "bad target dir exits non-zero" bash scripts/scaffold.sh "$TMP/nope" demo

printf '\n=== C. validate-workflow.sh ===\n'
fresh "$TMP/c0"; expect pass "pristine workflow passes" bash "$TMP/c0/harness/validate-workflow.sh"
# mutate <label> <file-rel> <sed-expr> — each mutation must make the gate FAIL.
mutate() {
  local d="$TMP/c$((++mi))"; fresh "$d"; edit "$d/$2" "$3"
  expect fail "rejects: $1" bash "$d/harness/validate-workflow.sh"
}
mi=0
mutate "undefined stage in a track"   harness/workflow/workflow.yaml 's/^  fast: \[spec,/  fast: [spek,/'
mutate "bad rollback target"          harness/workflow/workflow.yaml 's/to: design/to: desgin/'
mutate "bad next target"              harness/workflow/workflow.yaml 's/next: done$/next: dnoe/'
mutate "tier yaml↔contract drift"     harness/workflow/workflow.yaml 's/^  code-reviewer: medium/  code-reviewer: heavy/'
mutate "tier with no tier_models"     harness/workflow/workflow.yaml 's/^  pm: light/  pm: featherweight/'
mutate "contract missing ## Reads"    harness/workflow/roles/developer.md 's/^## Reads/## Inputs/'
mutate "produces not in contract"     harness/workflow/roles/qa-tester.md 's/qa-report\.md/qa.md/g'
d="$TMP/c$((++mi))"; fresh "$d"; cp assets/roles/pm.md "$d/harness/workflow/roles/ghost.md"
expect fail "rejects: orphan contract" bash "$d/harness/validate-workflow.sh"

printf '\n=== D. validate.sh template ===\n'
d="$TMP/d1"; fresh "$d"; cp assets/templates/validate.sh.template "$d/harness/validate.sh"
expect fail "raw template FAILS (vacuous PASS impossible)" bash "$d/harness/validate.sh"
expect fail "raw template FAILS --static too" bash "$d/harness/validate.sh" --static
# Fill it minimally: drop placeholder lines, put one real check in every category.
edit "$d/harness/validate.sh" '/\{\{/d; s/^([[:space:]]*)wired (A|B|B2|C)$/\1ok "\2 check"; wired \2/'
expect pass "filled template passes (full)"     bash "$d/harness/validate.sh"
expect pass "filled template passes --no-boot"  bash "$d/harness/validate.sh" --no-boot
expect pass "filled template passes --static"   bash "$d/harness/validate.sh" --static
printf '# SPEC — {{PROJECT_NAME}}\n' > "$d/SPEC.md"
expect fail "placeholder left in SPEC.md fails the gate" bash "$d/harness/validate.sh" --static
rm "$d/SPEC.md"; edit "$d/harness/validate.sh" 's/^ok "C check"; wired C$/wired C/'
expect fail "an empty category fails the gate" bash "$d/harness/validate.sh" --static

printf '\n=== E. Docs ↔ files ===\n'
for p in $(grep -oE '(assets|scripts|references)/[A-Za-z0-9_./-]+' SKILL.md README.md | cut -d: -f2 \
           | sed -E 's/[.,)]+$//' | sort -u); do
  case "$p" in *'*'*) continue ;; scripts/init.sh) continue ;; esac  # init.sh: generated in the target project
  [ -e "$p" ] && ok "referenced path exists: $p" || bad "SKILL/README reference missing: $p"
done

printf '\n'
if [ "$fail" -eq 0 ]; then printf 'SELF-GATE: PASS\n'; exit 0
else printf 'SELF-GATE: FAIL\n'; exit 1; fi
