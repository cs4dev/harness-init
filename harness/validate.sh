#!/usr/bin/env bash
# Self-gate for the harness-init skill: the skill's own "done = this exits 0".
# Runs the deterministic machinery (scaffold.sh, validate-workflow.sh, the
# validate.sh template) against throwaway repos and asserts both the PASS and the
# FAIL paths — a gate that never fails proves nothing.
#
# Categories: A syntax · B scaffold behavior · C workflow gate · D validate.sh
# template · E sub-agents + write guard · F mockup gate · G docs ↔ files ·
# H plugin packaging + stamps.
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
         harness/skills/resume.md docs/tasks harness/check-mockup.sh harness/workflow/mockup-starter.html; do
  [ -e "$TMP/b1/$p" ] && ok "wrote $p" || bad "missing $p"
done
[ -x "$TMP/b1/harness/validate-workflow.sh" ] && ok "validate-workflow.sh is executable" || bad "validate-workflow.sh not executable"
[ -x "$TMP/b1/harness/check-mockup.sh" ] && ok "check-mockup.sh is executable" || bad "check-mockup.sh not executable"
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
mutate "undefined optional stage"     harness/workflow/workflow.yaml 's/^  fast: \[spec, mockup\?,/  fast: [spec, mokup?,/'
mutate "bad rollback target"          harness/workflow/workflow.yaml 's/to: design/to: desgin/'
mutate "bad next target"              harness/workflow/workflow.yaml 's/next: done$/next: dnoe/'
mutate "tier yaml↔contract drift"     harness/workflow/workflow.yaml 's/^  code-reviewer: medium/  code-reviewer: heavy/'
mutate "tier with no tier_models"     harness/workflow/workflow.yaml 's/^  pm: light/  pm: featherweight/'
mutate "contract missing ## Reads"    harness/workflow/roles/developer.md 's/^## Reads/## Inputs/'
mutate "produces not in contract"     harness/workflow/roles/qa-tester.md 's/qa-report\.md/qa.md/g'
d="$TMP/c$((++mi))"; fresh "$d"; cp assets/roles/pm.md "$d/harness/workflow/roles/ghost.md"
expect fail "rejects: orphan contract" bash "$d/harness/validate-workflow.sh"
d="$TMP/c$((++mi))"; fresh "$d"; rm "$d/harness/check-mockup.sh"
expect fail "rejects: mockup stage without check-mockup.sh" bash "$d/harness/validate-workflow.sh"

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
grep -q '^model: opus$' "$d/.claude/agents/ux-designer.md" && ok "ux-designer → heavy → opus" || bad "ux-designer model wrong"
for r in requirements-analyst solution-architect ux-designer code-reviewer qa-tester; do
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

printf '\n=== F. check-mockup.sh ===\n'
d="$TMP/g1"; fresh "$d"; mk="$d/docs/tasks/T-001/mockup.html"
mkdir -p "$d/docs/tasks/T-001" "$d/docs/personas"
echo '# Persona — Field technician' > "$d/docs/personas/field-technician.md"
printf -- '- AC-1 next job one tap away\n- AC-2 offline state visible\n- AC-3 server rejects closed jobs\n' > "$d/docs/tasks/T-001/spec.md"
expect pass "no mockups yet → PASS" bash "$d/harness/check-mockup.sh"
cp assets/mockup-starter.html "$mk"
expect pass "starter (persona + spec in place) passes" bash "$d/harness/check-mockup.sh" "$d/docs/tasks/T-001"
expect pass "workflow gate passes with a valid mockup" bash "$d/harness/validate-workflow.sh"
# mock <label> <sed-expr> — each mutation of the starter must FAIL the checker.
mock() {
  edit_to() { sed -E "$1" assets/mockup-starter.html > "$mk"; }
  edit_to "$2"; expect fail "rejects: $1" bash "$d/harness/check-mockup.sh" "$d/docs/tasks/T-001"
}
mock "external script (CDN)"          's#<title>#<script src="https://cdn.example/x.js"></script><title>#'
mock "protocol-relative stylesheet"   's#<title>#<link rel="stylesheet" href="//fonts.example/f.css"><title>#'
mock "data-goto to no screen"         's#data-goto="signoff"#data-goto="sign-off"#'
mock "unreachable screen"             's#data-goto="done"#data-goto="jobs"#'
mock "duplicate screen id"            's#data-screen="done"#data-screen="job"#'
mock "no screens"                     's#data-screen=#data-view=#g'
mock "AC neither shown nor declared"  's#name="ac-non-visual" content="AC-3"#name="ac-non-visual" content=""#'
mock "cites an AC the spec lacks"     's#data-ac="AC-1"#data-ac="AC-1 AC-9"#'
mock "persona with no docs/personas/" 's#content="field-technician"#content="dispatcher"#'
mock "no persona meta"                's#<meta name="persona"[^>]*>##'
sed -E 's#<h1>Today#<!-- <a data-goto="ghost"></a> --><h1>Today#' assets/mockup-starter.html > "$mk"
expect pass "markup in comments is ignored" bash "$d/harness/check-mockup.sh" "$d/docs/tasks/T-001"
sed -E 's#data-goto="done"#data-goto="jobs"#' assets/mockup-starter.html > "$mk"
expect fail "workflow gate fails on a broken docs/tasks mockup" bash "$d/harness/validate-workflow.sh"
cp assets/mockup-starter.html "$mk"; rm "$d/docs/tasks/T-001/spec.md"
expect fail "rejects: mockup with no spec.md/design.md" bash "$d/harness/check-mockup.sh" "$d/docs/tasks/T-001"
grep -qE '\{\{[A-Z0-9_]+\}\}' assets/mockup-starter.html && bad "starter has a {{…}} placeholder (fails project gates' section 0)" || ok "starter has no {{…}} placeholder"

printf '\n=== G. Docs ↔ files ===\n'
for p in $(grep -oE '(assets|scripts|references)/[A-Za-z0-9_./-]+' skills/init/SKILL.md README.md | cut -d: -f2 \
           | sed -E 's/[.,)]+$//' | sort -u); do
  case "$p" in *'*'*) continue ;; scripts/init.sh) continue ;; esac  # init.sh: generated in the target project
  [ -e "$p" ] && ok "referenced path exists: $p" || bad "SKILL/README reference missing: $p"
done

printf '\n=== H. Plugin packaging + version stamps ===\n'
for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  expect pass "$j is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$j"
done
ver=$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json")).get("version",""))' 2>/dev/null)
printf '%s' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' && ok "plugin.json version is semver ($ver)" || bad "plugin.json version not semver: '$ver'"
python3 - <<'PY' && ok "marketplace lists harness at ./, no duplicate version" || bad "marketplace.json entry wrong (source ./, no version — plugin.json owns it)"
import json; m = json.load(open(".claude-plugin/marketplace.json"))
e = [p for p in m["plugins"] if p["name"] == "harness"]
assert len(e) == 1 and e[0]["source"] in ("./", ".") and "version" not in e[0]
PY
[ -f skills/init/SKILL.md ] && grep -q '^name: init$' skills/init/SKILL.md && ok "skill at skills/init (→ /harness:init)" || bad "skills/init/SKILL.md missing or misnamed"
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
cache="$TMP/cache/cs4dev/harness/$ver"; mkdir -p "$cache"
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
