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

This repo is a Claude Code marketplace (`harness-init`) that ships one plugin, `harness`. In a session
(Claude Code 2.1.275+):

```
/plugin install harness --marketplace cs4dev/harness-init
```

Older Claude Code, or from the shell:

```sh
claude plugin marketplace add cs4dev/harness-init
claude plugin install harness@harness-init     # --scope project to share via the repo
```

Then restart Claude Code or run `/reload-plugins`. The skill is `/harness:init`.

**Upgrading from 1.x (`/harness-init:init`):** the plugin was renamed from `harness-init`
to `harness` in 2.0.0. Remove the old one, then install as above:

```sh
claude plugin uninstall harness-init@harness-init
claude plugin marketplace update harness-init
```

Already-scaffolded projects are unaffected: their `v1.x` stamps still resolve as
upgrade's merge base.

**Upgrading from the old git-clone install:** remove the clone first. Otherwise it loads
as a second copy of the same plugin:

```sh
rm -rf ~/.claude/skills/harness-init
```

Projects you scaffolded from the clone keep working. Their SHA stamps still resolve as
upgrade's merge base (fetched from GitHub).

## Setup — one invocation per project

```
/harness:init web app, pnpm monorepo + Fastify + tRPC + React 19
/harness:init CLI tool in Go
/harness:init                 # existing repo: it scans and confirms the stack
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
harness/workflow/        three-track relay + 7 role contracts + the mockup starter
.claude/agents/          one sub-agent per role, rendered from workflow.yaml: model per
                         tier; reviewer/QA/analyst/architect/designer write only docs/tasks/
docs/personas/           GUI projects only: who uses the app (device, context, top tasks)
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

### Feature a persona will see — optional `mockup` stage

> T-009: technicians capture the customer's signature before closing a job

On a GUI project, the interview also captures **personas** (`docs/personas/*.md`), e.g. a
work-order app's *field technician* (phone, gloves, patchy signal), *dispatcher*
(desktop, many jobs at once) and *site contact* (emailed link, approves work). A task
that changes a screen or flow one of them uses gets `mockup` between spec/design and
dev:

`spec → mockup → (you approve) → dev → review ∥ qa`

The `ux-designer` builds `docs/tasks/T-009/mockup.html` **as the persona**: one
self-contained static HTML file, clickable screen to screen at the persona's viewport,
with real copy and the offline/error/empty states they'll hit. `check-mockup.sh` fails
it if it loads anything external, has an unreachable screen, or leaves an acceptance
criterion neither shown (`data-ac="AC-n"`) nor declared non-visual. You open it,
click through, and approve or send changes. Dev doesn't start without your yes. Dev then
builds to it, and QA walks the real app through the same screens as the persona.

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

## Upgrading an existing harness

Scaffolds are one-shot copies, so plugin improvements don't reach already-harnessed
projects on their own. Update the plugin, then run upgrade inside the project:

```sh
claude plugin marketplace update harness-init
claude plugin update harness@harness-init     # then restart, or /reload-plugins
```
```
/harness:init upgrade
```

To get new releases automatically, turn on auto-update in `/plugin` → Marketplaces →
harness-init → Enable auto-update. It is off by default for third-party marketplaces.

It refreshes only the generic machinery (`workflow.yaml`, role contracts, the
`validate-workflow.sh` / `sync-agents.sh` / write-guard / `check-mockup.sh` scripts and the
mockup starter, then re-renders
`.claude/agents/`), keeps your local edits to them, never touches SPEC/RULES/
`validate.sh`, re-runs the gate, and leaves one diff for you to commit. Needs a clean
git tree. Scaffolds record the release (`v1.2.0`) in `harness/workflow/.harness-version`.
A dev clone records its commit SHA instead. Upgrade fetches that ref from GitHub as the
merge base and does a real 3-way merge (`git merge-file`). Unstamped projects, or
upgrades run offline, fall back to a reviewed 2-way diff.

## Contributing

Work from a clone and load it in place: `claude --plugin-dir .`, or
`/plugin marketplace add ./` (a local marketplace is loaded without a cache copy).

The skill holds itself to its own rule: a change is done when `bash harness/validate.sh`
exits 0. It needs `python3` and the `claude` CLI (for `claude plugin validate`). It
scaffolds throwaway repos and asserts both paths — `scaffold.sh` output,
`validate-workflow.sh` rejecting broken workflows, the `validate.sh` template failing
until filled, plus the plugin manifests and version stamps. CI runs the same script on
Linux and macOS.

**Releases:** plugin users only receive an update when `version` in
`.claude-plugin/plugin.json` changes. The gate fails if shipped files (`skills/`,
`assets/`, `scripts/`, `references/`) changed since the current version's tag, so a
change to them must include a version bump. On merge to main, CI tags `v<version>`.
That tag is what scaffolds stamp and what upgrade fetches.

## Notes

- The gate will block real work. That is the point — fix the work, not the gate.
- Gate checks **fail** on missing prerequisites (DB down, `.env` absent). They never skip.
- B2 exists because "compiles" ≠ "runs": it boots the real artifact and probes it.
- Downstream never edits upstream. Blockers roll back through the PM.

See [skills/init/SKILL.md](skills/init/SKILL.md) for the full contract.
