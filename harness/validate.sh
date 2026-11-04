#!/usr/bin/env bash
# Self-gate for the harness-init skill: the skill's own "done = this exits 0".
# Runs the deterministic machinery (scaffold.sh, validate-workflow.sh, the
# validate.sh template) against throwaway repos and asserts both the PASS and the
# FAIL paths — a gate that never fails proves nothing.
#
# Categories: A syntax · B scaffold behavior · C workflow gate · D validate.sh
# template · E sub-agents + write guard · F docs ↔ files · G plugin packaging + stamps.
# Same conventions as the gates it ships: set -uo pipefail without -e,
# [[:space:]] not \s, no GNU-only flags (CI runs Linux + macOS).
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

printf '\n=== E. Sub-agents (.claude/agents) ===\n'
d="$TMP/f1"; fresh "$d"
n_agents=$(ls "$d/.claude/agents" | wc -l | tr -d ' ')
[ "$n_agents" = "$(( $(ls assets/roles | wc -l) - 1 ))" ] && ok "one agent per role except pm ($n_agents)" || bad "agents rendered: $n_agents"
[ ! -e "$d/.claude/agents/pm.md" ] && ok "no pm agent (PM is the main session)" || bad "pm.md rendered"
grep -q '^model: opus$' "$d/.claude/agents/developer.md" && ok "developer → heavy → opus" || bad "developer model wrong"
grep -q '^model: sonnet$' "$d/.claude/agents/code-reviewer.md" && ok "code-reviewer → medium → sonnet" || bad "code-reviewer model wrong"
for r in requirements-analyst solution-architect code-reviewer qa-tester; do
  grep -q 'guard-artifact-write.sh' "$d/.claude/agents/$r.md" && ok "$r has the write guard" || bad "$r missing the write guard"
done
grep -q 'hooks:' "$d/.claude/agents/developer.md" && bad "developer is guarded (it owns code)" || ok "developer unguarded"
# guard <want> <path> — feed the hook a Write call, as Claude Code would.
guard() {
  local want=$1 p=$2
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$p" \
    | CLAUDE_PROJECT_DIR="$d" bash "$d/harness/guard-artifact-write.sh" >/dev/null 2>&1
  local rc=$?; { [ "$want" = allow ] && [ $rc -eq 0 ]; } || { [ "$want" = block ] && [ $rc -eq 2 ]; } \
    && ok "guard ${want}s ${p#$d/}" || bad "guard on ${p#$d/}: exit $rc, wanted $want"
}
guard allow "$d/docs/tasks/T-001/review.md"
guard allow "docs/tasks/T-001/qa-report.md"
guard block "$d/src/app.ts"
guard block "$d/SPEC.md"
guard block "$d/docs/tasks/../src/escape.ts"
expect pass "pristine agents pass --check" bash "$d/harness/sync-agents.sh" --check
edit "$d/harness/workflow/workflow.yaml" 's/^  heavy: opus/  heavy: fable/'
expect fail "tier_models change without re-sync fails the workflow gate" bash "$d/harness/validate-workflow.sh"
expect pass "re-sync fixes it" bash "$d/harness/sync-agents.sh"
grep -q '^model: fable$' "$d/.claude/agents/developer.md" && ok "re-sync rendered the new model" || bad "re-sync left old model"
edit "$d/.claude/agents/qa-tester.md" 's/^model: .*/model: haiku/'
expect fail "hand-edited agent file is caught" bash "$d/harness/sync-agents.sh" --check
bash "$d/harness/sync-agents.sh" >/dev/null 2>&1
expect pass "re-sync restores it" bash "$d/harness/sync-agents.sh" --check
printf -- '---\nname: developer\n---\nmine\n' > "$d/.claude/agents/developer.md"
expect fail "user's own same-named agent is not overwritten" bash "$d/harness/sync-agents.sh"
grep -q '^mine$' "$d/.claude/agents/developer.md" && ok "user agent left intact" || bad "user agent overwritten"

printf '\n=== F. Docs ↔ files ===\n'
for p in $(grep -oE '(assets|scripts|references)/[A-Za-z0-9_./-]+' skills/init/SKILL.md README.md | cut -d: -f2 \
           | sed -E 's/[.,)]+$//' | sort -u); do
  case "$p" in *'*'*) continue ;; scripts/init.sh) continue ;; esac  # init.sh: generated in the target project
  [ -e "$p" ] && ok "referenced path exists: $p" || bad "SKILL/README reference missing: $p"
done

printf '\n=== G. Plugin packaging + version stamps ===\n'
for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  expect pass "$j is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$j"
done
ver=$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json")).get("version",""))' 2>/dev/null)
printf '%s' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' && ok "plugin.json version is semver ($ver)" || bad "plugin.json version not semver: '$ver'"
python3 - <<'PY' && ok "marketplace lists harness-init at ./, no duplicate version" || bad "marketplace.json entry wrong (source ./, no version — plugin.json owns it)"
import json; m = json.load(open(".claude-plugin/marketplace.json"))
e = [p for p in m["plugins"] if p["name"] == "harness-init"]
assert len(e) == 1 and e[0]["source"] in ("./", ".") and "version" not in e[0]
PY
[ -f skills/init/SKILL.md ] && grep -q '^name: init$' skills/init/SKILL.md && ok "skill at skills/init (→ /harness-init:init)" || bad "skills/init/SKILL.md missing or misnamed"
[ ! -e SKILL.md ] && ok "no root SKILL.md (would shadow the skills/ layout)" || bad "root SKILL.md present"
if command -v claude >/dev/null 2>&1; then
  expect pass "claude plugin validate --strict ." claude plugin validate --strict .
else bad "claude CLI not on PATH — needed for plugin validate (npm i -g @anthropic-ai/claude-code)"; fi
# A release tag must name exactly what a cache copy of that version contains.
if git rev-parse -q --verify "refs/tags/v$ver" >/dev/null; then
  git diff --quiet "v$ver" -- skills assets scripts references .claude-plugin \
    && ok "shipped files unchanged since v$ver" \
    || bad "shipped files changed since tag v$ver — bump version in plugin.json"
else ok "v$ver not tagged yet (CI tags it on main)"; fi

# Stamps: a dev clone stamps its SHA; a cache copy (no .git) stamps v<version>.
head=$(git rev-parse HEAD)
d="$TMP/g1"; fresh "$d"
if [ -z "$(git status --porcelain assets)" ]; then
  [ "$(cat "$d/harness/workflow/.harness-version" 2>/dev/null)" = "$head" ] && ok "clone install stamps HEAD SHA" || bad "clone stamp: $(cat "$d/harness/workflow/.harness-version" 2>/dev/null)"
else ok "assets/ dirty locally — SHA stamp check runs on a clean tree"; fi
cache="$TMP/cache/harness-init/harness-init/$ver"; mkdir -p "$cache"
git archive HEAD | tar -x -C "$cache"
cp -R assets scripts .claude-plugin "$cache"/   # working-tree copy, like an install would be
d="$TMP/g2"; mkdir -p "$d"; bash "$cache/scripts/scaffold.sh" "$d" demo >/dev/null 2>&1
[ "$(cat "$d/harness/workflow/.harness-version" 2>/dev/null)" = "v$ver" ] && ok "cache install stamps v$ver" || bad "cache stamp: $(cat "$d/harness/workflow/.harness-version" 2>/dev/null)"
mkdir -p "$TMP/dotfiles/nested" && git -C "$TMP/dotfiles" init -q && cp -R "$cache"/. "$TMP/dotfiles/nested"/
[ "$(bash "$TMP/dotfiles/nested/scripts/version.sh" current 2>/dev/null)" = "v$ver" ] \
  && ok "copy nested in an unrelated repo still stamps v$ver" || bad "nested copy stamped a foreign repo's HEAD"

# Bases: resolve a SHA locally, a SHA and a tag remotely (file:// stands in for GitHub).
expect pass "base <HEAD> from local checkout" bash scripts/version.sh base "$head" "$TMP/base1"
cmp -s "$TMP/base1/assets/workflow.yaml" <(git show HEAD:assets/workflow.yaml) && ok "local base content = HEAD" || bad "local base content differs"
git clone -q --bare "$ROOT" "$TMP/remote.git" && git -C "$TMP/remote.git" tag v0.0.0-test "$head"
export HARNESS_REPO="file://$TMP/remote.git"
expect pass "base <SHA> fetched remotely by a cache copy" bash "$cache/scripts/version.sh" base "$head" "$TMP/base2"
expect pass "base <tag> fetched remotely by a cache copy" bash "$cache/scripts/version.sh" base v0.0.0-test "$TMP/base3"
cmp -s "$TMP/base3/assets/workflow.yaml" <(git show HEAD:assets/workflow.yaml) && ok "fetched base content = tagged commit" || bad "fetched base content differs"
expect fail "unknown ref fails (→ 2-way fallback)" bash "$cache/scripts/version.sh" base v99.0.0 "$TMP/base4"
unset HARNESS_REPO

printf '\n'
if [ "$fail" -eq 0 ]; then printf 'SELF-GATE: PASS\n'; exit 0
else printf 'SELF-GATE: FAIL\n'; exit 1; fi
