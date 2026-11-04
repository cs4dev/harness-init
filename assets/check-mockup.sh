#!/usr/bin/env bash
# Mockup gate (workflow stage `mockup`, role ux-designer). Checks a task's
# docs/tasks/<id>/mockup.html against the conventions in roles/ux-designer.md:
#   - self-contained: no external URLs (it must open from file:// with no network)
#   - persona: <meta name="persona"> names slugs that exist in docs/personas/
#   - flow: data-screen ids unique, every data-goto lands on a screen, every screen
#           reachable from the first one
#   - coverage: every AC-n in the task's spec.md/design.md appears in a data-ac or in
#           <meta name="ac-non-visual">, and the mockup cites no AC the spec lacks
# Markup inside <script> and <!-- --> is ignored for the flow/coverage scan.
#
# Usage: check-mockup.sh <task-dir|mockup.html>…   check those
#        check-mockup.sh                          check every docs/tasks/*/mockup.html
#                                                 (none → PASS; called by validate-workflow.sh)
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; fail=1; }

# meta <file> <name> — content of <meta name="<name>" content="…">, either attribute order.
meta() {
  tr '\n' ' ' < "$1" | grep -oiE "<meta[^>]*name=[\"']$2[\"'][^>]*>" | head -1 \
    | grep -oiE "content=[\"'][^\"']*[\"']" | sed -E "s/^content=[\"']//; s/[\"']$//"
}

check() {  # check <mockup.html>
  local f=$1 dir specs acs nonvis personas p ext out
  dir=$(dirname "$f")
  printf '=== Mockup %s ===\n' "$f"
  [ -f "$f" ] || { bad "missing $f"; return; }

  ext=$(grep -noiE "((src|href|srcset|action|poster)[[:space:]]*=[[:space:]]*[\"']?(https?:)?//|url\([[:space:]]*[\"']?(https?:)?//|@import)" "$f" | head -3)
  [ -z "$ext" ] && ok "self-contained (no external URLs)" || bad "external reference (line:match): $(echo $ext)"

  personas=$(meta "$f" persona)
  if [ -z "$personas" ]; then bad 'no <meta name="persona" content="<slug>"> (which persona is this for?)'
  else
    for p in $personas; do
      [ -f "docs/personas/$p.md" ] && ok "persona $p (docs/personas/$p.md)" || bad "persona '$p' has no docs/personas/$p.md"
    done
  fi

  specs=""; for s in "$dir/design.md" "$dir/spec.md"; do [ -f "$s" ] && specs="$specs $s"; done
  if [ -z "$specs" ]; then bad "no spec.md/design.md next to the mockup"; acs=""
  else
    acs=$(cat $specs | grep -oE 'AC-[0-9]+' | sort -u | tr '\n' ' ')
    [ -n "$acs" ] || bad "spec has no AC-n ids (analyst/architect number criteria AC-1, AC-2, …)"
  fi
  nonvis=$(meta "$f" ac-non-visual)

  # One pass over the markup: strip <script>/comments, then walk the data-* tokens in
  # document order. A goto belongs to the last screen opened before it; gotos before
  # the first screen are shared chrome, reachable from every screen.
  out=$(SPEC_ACS="$acs" NONVIS="$nonvis" awk -v q="'" '
    { doc = doc $0 "\n" }
    function strip(from, upto,   lo, i, j, r) {
      r = ""; lo = tolower(doc)
      while ((i = index(lo, from)) > 0) {
        r = r substr(doc, 1, i - 1)
        j = index(substr(lo, i), upto); if (j == 0) { doc = ""; return r }
        doc = substr(doc, i + j - 1 + length(upto)); lo = substr(lo, i + j - 1 + length(upto))
      }
      return r doc
    }
    END {
      doc = strip("<!--", "-->"); doc = strip("<script", "</script>")
      ns = 0; cur = ""; qs = "[\"" q "]"; nq = "[^\"" q "]*"
      while (match(doc, "data-(screen|goto|ac)[[:space:]]*=[[:space:]]*" qs nq qs)) {
        tok = substr(doc, RSTART, RLENGTH); doc = substr(doc, RSTART + RLENGTH)
        kind = tok; sub(/^data-/, "", kind); sub(/[[:space:]]*=.*/, "", kind)
        val = tok; sub("^" nq qs, "", val); sub(qs "$", "", val)
        if (kind == "screen") {
          if (val in screen) print "BAD duplicate screen id \"" val "\""
          screen[val] = 1; order[++ns] = val; cur = val
        } else if (kind == "goto") {
          edges[++ne] = cur SUBSEP val; target[val] = 1
        } else {
          n = split(val, a, /[[:space:]]+/); for (k = 1; k <= n; k++) if (a[k] != "") cited[a[k]] = 1
        }
      }
      if (ns == 0) { print "BAD no <section data-screen=\"…\"> screens"; exit }
      print "OK " ns " screens, start = " order[1]
      for (t in target) if (!(t in screen)) print "BAD data-goto=\"" t "\" lands on no screen"
      # Reachability from the first screen (shared-chrome gotos count from anywhere).
      seen[order[1]] = 1; changed = 1
      while (changed) { changed = 0
        for (e = 1; e <= ne; e++) { split(edges[e], pr, SUBSEP)
          if ((pr[1] == "" || pr[1] in seen) && (pr[2] in screen) && !(pr[2] in seen)) { seen[pr[2]] = 1; changed = 1 } } }
      for (s = 1; s <= ns; s++) if (!(order[s] in seen)) print "BAD screen \"" order[s] "\" unreachable from " order[1]
      n = split(ENVIRON["NONVIS"], nv, /[[:space:]]+/); for (k = 1; k <= n; k++) if (nv[k] != "") nonvis[nv[k]] = 1
      n = split(ENVIRON["SPEC_ACS"], sa, /[[:space:]]+/)
      for (k = 1; k <= n; k++) if (sa[k] != "") { spec[sa[k]] = 1
        if (!(sa[k] in cited) && !(sa[k] in nonvis)) print "BAD " sa[k] " neither shown (data-ac) nor declared ac-non-visual" }
      for (c in cited)  if (!(c in spec)) print "BAD data-ac cites " c ", which the spec does not define"
      for (c in nonvis) if (!(c in spec)) print "BAD ac-non-visual lists " c ", which the spec does not define"
    }' "$f") || out="BAD markup scan failed (awk exit $?)"
  case "$out" in *BAD*|*"OK "*screens*) ;; *) out="$out
BAD markup scan produced no screen summary" ;; esac
  case "$out" in *BAD*) ;; *) [ -n "$acs" ] && out="$out
OK acceptance criteria covered: $acs" ;; esac
  while IFS= read -r line; do
    case "$line" in OK\ *) ok "${line#OK }" ;; BAD\ *) bad "${line#BAD }" ;; esac
  done <<EOF
$out
EOF
}

if [ $# -eq 0 ]; then
  set -- docs/tasks/*/mockup.html
  [ -e "$1" ] || { printf '=== Mockups ===\n  - none under docs/tasks/\n\nMOCKUP: PASS\n'; exit 0; }
fi
for t in "$@"; do
  [ -d "$t" ] && t="${t%/}/mockup.html"
  check "$t"
done

[ "$fail" -eq 0 ] && { printf '\nMOCKUP: PASS\n'; exit 0; } || { printf '\nMOCKUP: FAIL\n'; exit 1; }
