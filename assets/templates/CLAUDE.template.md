# {{PROJECT_NAME}} — Harness Index

This repo is built **harness-first**: the human builds the harness, the AI writes the production code. Read these on entry, in order.

## Session start
Follow `harness/skills/resume.md` ONCE per session: git state → task-board → baseline
gate (`--no-boot`) → resume from the task's routing log. The board and git are the
truth, not chat memory.

## Read first, every task
1. **[harness/context.md](harness/context.md)** — the 30-line digest (commands, frozen-rule one-liners, file map). Sub-agents read THIS first; full SPEC/RULES only where the task touches them.
2. **[SPEC.md](SPEC.md)** — what v1 is. FROZEN. The only source of truth for scope + behavior.
3. **[RULES.md](RULES.md)** — hard boundaries. R1 (Definition of Done) is non-negotiable.
4. **[docs/dev-map.md](docs/dev-map.md)** — where code lives + conventions. Read before writing code.
5. **[docs/task-board.md](docs/task-board.md)** — task history + current stage.

## Skills (SOPs — don't improvise these)
- `harness/skills/resume.md` — start-of-session bootstrap.
- `harness/skills/run.md` — run the whole app.
- `harness/skills/build.md` — how to build.
- `harness/skills/test.md` — how to test.
- `harness/skills/validate.md` — how to run the master gate (modes: full / `--no-boot` / `--static`).

## Workflow (Level 3 — structured orchestration)
- `harness/workflow/workflow.yaml` — tracks (solo/fast/full — fast is the default; solo for trivial mechanical changes; full only on explicit triggers), stages, rollback triggers. PM routes; downstream never edits upstream.
- Boot budget: ONE boot per task — dev `--no-boot`, reviewer `--static`, QA full gate (solo: dev runs the full gate, it's the only verdict).
- `harness/workflow/roles/*.md` — per-agent contracts (Reads / Produces / Blocker / Escalate / Model tier).
- `harness/validate-workflow.sh` — keeps the definition and contracts in sync (also Category D of the master gate).
- Per-task stage artifacts live under `docs/tasks/<id>/`.

## The hard gate
`harness/validate.sh` is the objective judge of "done". Per RULES R1, a task is complete only when it exits 0. Not on a verbal claim.
CI (`.github/workflows/harness-gate.yml`) runs the SAME script on push/PR — it adds no checks of its own. A check CI needs belongs in validate.sh, where the developer hits it first.

## Maintenance
Whoever changes code updates `dev-map`. Whoever owns the task updates `task-board`. The harness lives in git, not in chat memory.
