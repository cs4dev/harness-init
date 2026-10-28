# Upgrade — existing harness → this skill's current assets

Scaffolds are one-shot copies; this pulls later skill changes into a harnessed project.
Scope is the VERBATIM assets only — they're the harness's generic machinery:
`assets/workflow.yaml` → `harness/workflow/workflow.yaml`,
`assets/roles/*.md` → `harness/workflow/roles/`,
`assets/validate-workflow.sh` → `harness/validate-workflow.sh`,
`assets/sync-agents.sh` / `assets/guard-artifact-write.sh` → `harness/`. Instantiated files
(SPEC, RULES, validate.sh, CLAUDE.md, CI, context.md, skills) are project-owned —
never touch them; if their template changed, just tell the user what changed.

1. Precondition: clean git tree (upgrade must be one reviewable, revertable diff).
   Not a git repo or dirty → stop and say so.
2. Read the merge base from `harness/workflow/.harness-version`. Usable only if
   `git -C <skill dir> cat-file -e <hash>` succeeds (missing stamp, or a commit the
   skill checkout doesn't have, e.g. shallow clone → 2-way fallback, step 5).
3. Per asset: identical to the skill's current copy → skip silently. Missing in
   project → copy it in, unless it existed at base (the project deleted it on
   purpose) → ask before restoring.
4. **3-way (base usable):** `git -C <skill dir> show <hash>:assets/<path> > base`
   (absent at base = new asset, step 3), then `git merge-file <project file> base
   <skill file>` — merges in place, exit code = conflict count. Exit 0 → merged,
   local edits kept automatically. Conflicts → show each `<<<<<<<` block and
   AskUserQuestion (skill / local / hand-merged); never leave markers in the file.
5. **2-way fallback (no base):** show the diff and classify each hunk: **skill
   change** vs **local edit** (e.g. a swapped `tier_models`). Take skill hunks, keep
   local edits; any hunk you can't classify → AskUserQuestion. Never silently drop a
   local edit.
6. A role the project added that the skill doesn't ship → leave it alone.
7. Run `bash harness/sync-agents.sh` (re-renders `.claude/agents/` from the merged
   workflow.yaml; reports a same-named agent the user wrote by hand — ask before
   renaming either), then `harness/validate-workflow.sh` then `harness/validate.sh --static`; both must
   exit 0. Then rewrite `.harness-version` with the skill's current HEAD (same
   dirty-assets rule as scaffolding). Report per file: unchanged / updated / merged /
   conflict-resolved / kept-local, and which mode ran (3-way or 2-way).
8. Suggest a commit ("harness: upgrade workflow assets") — the user decides.

