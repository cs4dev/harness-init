<p align="center">
  <img src="assets/logo.svg" width="120" alt="harness-init">
</p>

<h1 align="center">harness-init</h1>

<p align="center"><em>A task is done when the gate exits 0 — never on a verbal claim.</em></p>

Claude Code skill that scaffolds a Level-3 Harness Engineering setup into any project:
frozen SPEC, RULES, role SOPs, a master validation gate, and a three-track multi-agent
workflow (solo / fast / full).

Core idea: **the human owns the harness, the AI writes the code.** The harness is the
durable asset — it lives in git, not in chat memory.

## Install

```sh
git clone https://github.com/cs4dev/harness-init.git ~/.claude/skills/harness-init
```

## Setup — one invocation per project

```
/harness-init web app, pnpm monorepo + Fastify + tRPC + React 19
/harness-init CLI tool in Go
/harness-init                      # existing repo: it scans and confirms the stack
```

Stack resolution: invocation argument → repo scan (detect, confirm) → for empty repos,
it recommends 2-3 stacks for you to pick. Then it interviews you for the frozen parts —
v1 scope, the correctness core (what data must never be corrupted, what logic exists
exactly once), and 10-15 binary acceptance criteria — and generates:

```
SPEC.md                  frozen v1, only after your sign-off
RULES.md                 ~10 red lines, each mechanically checkable one gets a gate grep
harness/validate.sh      the gate: A build · B tests · B2 boot the artifact · C rules · D workflow sync
harness/context.md       ~30-line digest every sub-agent reads first
harness/workflow/        three-track relay + 6 role contracts
docs/task-board.md       append-only, one task active at a time
.github/workflows/       CI materializes prerequisites, then runs the same gate
```

On an empty repo it also writes a walking skeleton — the minimum code that makes every
gate category judge something real, so the first PASS is earned rather than vacuous.

## Day-2 — the loop

Every session starts with `harness/skills/resume.md`: git state → task-board → baseline
`validate.sh --no-boot`. The board and git are the truth, not chat memory.

Each new piece of work is a task `T-00X`. You (as PM, in the main session) write
`docs/tasks/T-00X/task.md`, and the track is picked mechanically — simplest that fits,
promote-never-demote:

### Feature — `fast` track (the default)

> T-004: users can export their trip history as CSV

`spec → dev → review ∥ qa`. The requirements-analyst writes one `spec.md`, the developer
implements against it, then reviewer and QA run **in parallel**. Done needs both
verdicts; either failure rolls back to dev and both re-run.

### Feature touching the frozen core — `full` track

> T-007: add a `POST /transfers` endpoint moving balance between two accounts

Promoted because it hits an explicit trigger: new endpoint, schema change, migration,
edits to frozen SPEC/RULES, a cross-package contract, or a new external dependency.
Adds a `design` stage — the solution-architect writes binary acceptance criteria and the
design in one artifact before any code exists.

### Bug fix — usually `fast`, sometimes `solo`

> T-011: fix — refunds above the original charge are accepted

A fix that touches correctness-core logic stays on `fast` so QA independently re-runs the
gate. Add the failing test first; it's the acceptance criterion. Bugs you spot mid-task
never get silently fixed — they're logged to the board's *Bugs spotted* section the
moment they're found, then triaged into a task or deferred.

### Trivial mechanical change — `solo` track

> bump the log level, rename a variable, fix a typo in a route string

No sub-agents. The main session implements and the **full gate is the only verdict** —
no self-grading.

### One boot per task

Booting the artifact is the slow check, so it happens exactly once:

| stage | command | covers |
|---|---|---|
| dev | `validate.sh --no-boot` | A + B + C + D |
| reviewer | `validate.sh --static` | A + C + D |
| QA | `validate.sh` | everything, incl. the boot |

On `solo`, the main session just runs the full gate.

## Notes

- The gate will block real work. That is the point — fix the work, not the gate.
- Gate checks **fail** on missing prerequisites (DB down, `.env` absent). They never skip.
- B2 exists because "compiles" ≠ "runs": it boots the real artifact and probes it.
- Downstream never edits upstream. Blockers roll back through the PM.

See [SKILL.md](SKILL.md) for the full contract.
