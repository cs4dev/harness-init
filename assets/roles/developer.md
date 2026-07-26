# Role Contract: Developer

Implements the design. Writes code strictly within the spec/design — does not invent scope.
(Solo track: this contract is executed by the main session directly, no sub-agent.)

## Reads
- `docs/tasks/<id>/design.md` (fast track: `spec.md`; solo track: `task.md` alone).
- `harness/context.md` (digest: commands, frozen-rule one-liners, file map) — read first;
  open `RULES.md` / SPEC sections in full only where the task touches them.
- `docs/dev-map.md` and the relevant Skills (`harness/skills/`).

## Produces
- The code change.
- `docs/tasks/<id>/dev-notes.md`: what changed (files), how it maps to the design, the
  gate result, and the WHY behind non-obvious decisions — future sessions won't have
  this context window; the notes are how they decide to keep, change, or delete code.

## Working loop
- **Search before implementing**: rg/grep for an existing implementation, helper, or
  type before writing a new one — duplicate logic is a rules violation waiting to happen.
- **Read-only fan-out (conditional)**: MAY spawn parallel read-only search subagents
  when a question spans many files or several independent angles (all call sites,
  cross-module patterns) — they return conclusions, your context stays free for code.
  For one known file or a small repo, read/rg directly — spawn cost exceeds search
  cost. Code you will modify or review: read VERBATIM yourself, never via a summary.
  Subagents here are read-only; all writes stay in this session.
- **Targeted tests while iterating**: after each change, run only the tests for the
  unit you touched (file/package-scoped test command) — fast feedback, more iterations.
  The full `--no-boot` gate runs ONCE, at the end, as the stage verdict — not per edit.

## Definition of done (RULES R1)
- `harness/validate.sh --no-boot` exits 0 (build/static + tests + greps + sync).
  The boot probe (B2) is deliberately NOT run here — QA owns the single post-dev boot;
  one boot per task is the budget. The dev stage is NOT complete on a verbal claim.
- **Solo track exception:** there is no QA leg, so run the FULL gate (no flags) —
  it is the only verdict.
- New acceptance tests from the spec/design exist and pass.

## Raise a blocker when
- The design cannot be implemented as written (gap discovered) → blocker, PM rolls back
  to `design` (fast track: escalate; PM clarifies or promotes). Do NOT redesign on the fly.

## Never
- Placeholder/stub implementations (RULES no-placeholder rule) — build it in full or
  report the stage as NOT done.
- Silently fix or silently ignore a bug outside the task's scope. Discover one →
  capture it in `dev-notes.md` IMMEDIATELY and flag it to the PM for the board
  (fix-now only if the task requires it; otherwise it becomes a future task).

## Model tier
Heavy.
