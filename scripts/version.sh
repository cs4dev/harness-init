#!/usr/bin/env bash
# The version stamp in harness/workflow/.harness-version is upgrade's 3-way merge base.
# A plugin install is a plain copy in ~/.claude/plugins/cache (no .git), so the stamp
# can't assume a local checkout: it names a commit SHA when the plugin root IS its own
# git checkout (a dev clone), else the release tag v<version> from plugin.json. Release
# tags are pushed by CI, and the self-gate fails when shipped files change without a
# version bump — so a tag always names exactly what a cache copy of it contains.
#
# Usage:
#   version.sh current            print the stamp for this plugin copy (exit 1: none valid)
#   version.sh base <ref> <dir>   materialize <ref>'s assets/ into <dir>/assets
#                                 (local checkout first, else fetch from $HARNESS_REPO)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${HARNESS_REPO:-https://github.com/cs4dev/harness-init.git}"

# own_checkout — true only when ROOT is the top of its own repo (a cache dir nested
# in a dotfiles repo under ~ must not stamp that repo's HEAD).
own_checkout() {
  local top; top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$ROOT" && pwd -P)" ]
}

plugin_version() {
  sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
    "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1
}

case "${1:-}" in
  current)
    if own_checkout; then
      [ -z "$(git -C "$ROOT" status --porcelain assets)" ] \
        || { echo "assets/ is dirty — HEAD would not match what was copied" >&2; exit 1; }
      git -C "$ROOT" rev-parse HEAD
    else
      v=$(plugin_version)
      [ -n "$v" ] || { echo "no git checkout and no version in plugin.json" >&2; exit 1; }
      printf 'v%s\n' "$v"
    fi ;;
  base)
    [ $# -eq 3 ] || { echo "usage: $0 base <ref> <dir>" >&2; exit 2; }
    ref=$2; out=$3; mkdir -p "$out" || exit 1
    if own_checkout && git -C "$ROOT" cat-file -e "$ref^{commit}" 2>/dev/null; then
      git -C "$ROOT" archive "$ref" assets | tar -x -C "$out" && { echo "base $ref: local checkout"; exit 0; }
    fi
    g=$(mktemp -d); trap 'rm -rf "$g"' EXIT
    git -C "$g" init -q \
      && git -C "$g" fetch -q --depth 1 "$REPO" "$ref" 2>/dev/null \
      && git -C "$g" archive FETCH_HEAD assets | tar -x -C "$out" \
      && { echo "base $ref: fetched from $REPO"; exit 0; }
    echo "base $ref: not resolvable (offline, or unknown ref) — use the 2-way fallback" >&2
    exit 1 ;;
  *) echo "usage: $0 current | base <ref> <dir>" >&2; exit 2 ;;
esac
