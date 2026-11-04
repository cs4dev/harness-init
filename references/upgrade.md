# Upgrade — existing harness → this plugin's current assets

Scaffolds are one-shot copies; this pulls later plugin changes into a harnessed project.
`<plugin root>` below = the `${CLAUDE_PLUGIN_ROOT}` path SKILL.md gave you.
Scope is the VERBATIM assets only — they're the harness's generic machinery:
`assets/workflow.yaml` → `harness/workflow/workflow.yaml`,
`assets/roles/*.md` → `harness/workflow/roles/`,
`assets/validate-workflow.sh` → `harness/validate-workflow.sh`,
`assets/sync-agents.sh` / `assets/guard-artifact-write.sh` / `assets/check-mockup.sh` → `harness/`,
`assets/mockup-starter.html` → `harness/workflow/mockup-starter.html`. Instantiated files
(SPEC, RULES, validate.sh, CLAUDE.md, CI, context.md, skills) are project-owned —
never touch them; if their template changed, just tell the user what changed.

0. The plugin copy must be current first: if the user hasn't, suggest
   `claude plugin update harness@harness-init` (then restart / `/reload-plugins`).
1. Precondition: clean git tree (upgrade must be one reviewable, revertable diff).
   Not a git repo or dirty → stop and say so.
2. Read the merge base from `harness/workflow/.harness-version` — a release tag
   (`v1.2.0`) or a commit SHA (dev clones, and pre-plugin scaffolds). Materialize it:
   `bash <plugin root>/scripts/version.sh base <stamp> <tmp dir>` (checks a local
   checkout, else fetches the ref from GitHub). Exit 0 → base files are at
   `<tmp dir>/assets/<path>`. Missing stamp or non-zero exit (offline, unknown ref)
   → 2-way fallback, step 5 — say which and why.
3. Per asset: identical to the plugin's current copy → skip silently. Missing in
   project → copy it in, unless it existed at base (the project deleted it on
   purpose) → ask before restoring.
4. **3-way (base usable):** with `base = <tmp dir>/assets/<path>` (absent at base =
   new asset, step 3), `git merge-file <project file> base <plugin root>/assets/<path>`
   — merges in place, exit code = conflict count. Exit 0 → merged,
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
   exit 0. Then rewrite `.harness-version` with the output of
   `bash <plugin root>/scripts/version.sh current`; if that exits non-zero, delete the
   stamp (an old one would be a wrong merge base) and say why. Report per file: unchanged / updated / merged /
   conflict-resolved / kept-local, and which mode ran (3-way or 2-way).
8. New capability, project-owned side: if the upgrade brought in the `mockup` stage and
   the project has a web/GUI client but no `docs/personas/`, say so and offer the
   persona interview (SKILL.md Q5) → `docs/personas/<slug>.md` from
   `assets/templates/docs/persona.md`, plus the context.md Personas section. Without
   personas the stage never triggers — the upgrade is still complete.
9. Suggest a commit ("harness: upgrade workflow assets") — the user decides.

