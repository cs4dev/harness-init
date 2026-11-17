<p align="center">
  <img src="assets/logo.svg" width="120" alt="harness-init">
</p>

<h1 align="center">harness-init</h1>

<p align="center"><em>A task is done when the gate exits 0, not when someone says it is.</em></p>

`harness` is a Claude Code plugin. Its one skill, `/harness:init`, adds a harness to any
project. A harness is the set of files that keeps AI-written code honest:

- **SPEC.md**: the v1 scope, frozen after you sign it off.
- **RULES.md**: about 10 red lines the code must never cross.
- **harness/validate.sh**: one gate script that decides whether work is done.
- **A multi-agent workflow**: role sub-agents (analyst, developer, reviewer, QA, …) that
  pass each task along a fixed relay.

The idea behind it: **you own the harness, the AI writes the code.** The harness lives in
git, not in chat memory, so it outlasts any single session.

## Install

Requires Claude Code 2.1.275 or later. In a Claude Code session:

```
/plugin install harness --marketplace cs4dev/harness-init
```

Or from the shell:

```sh
claude plugin marketplace add cs4dev/harness-init
claude plugin install harness@cs4dev     # add --scope project to share it via the repo
```

Then restart Claude Code or run `/reload-plugins`.

## Quick start

Run the skill once per project, in the project's root:

```
/harness:init web app, pnpm monorepo + Fastify + tRPC + React 19
/harness:init CLI tool in Go
/harness:init                 # existing repo: it detects the stack and asks you to confirm
```

How it settles on the stack:

1. If you typed one after the command, it uses that.
2. Otherwise it scans the existing repo and asks you to confirm what it found.
3. On an empty repo, it suggests 2-3 stacks and you pick one.

It then asks you a short set of questions:

- **Scope**: what is in v1, and what is explicitly out.
- **Correctness core**: what data must never be corrupted, and what logic must exist
  exactly once.
- **Acceptance**: 10-15 pass/fail criteria for v1. It drafts them; you approve them.

Nothing frozen is written until you sign off. When it finishes, the gate passes on the
fresh scaffold. **Restart Claude Code before your first task**: the role sub-agents only
load at session start. `claude --continue` restarts and keeps the conversation.

## What you get

```
SPEC.md                  frozen v1, written only after your sign-off
RULES.md                 ~10 red lines; each one that can be checked mechanically gets a gate grep
harness/validate.sh      the gate (categories below)
harness/context.md       ~30-line digest every sub-agent reads first
harness/skills/          short SOPs: resume, run, build, test, validate
harness/workflow/        the three-track workflow, 7 role contracts, the mockup starter
.claude/agents/          one sub-agent per role, generated from workflow.yaml
.claude/settings.json    pre-approves the harness scripts and your stack's commands
docs/task-board.md       append-only board, one task active at a time
docs/personas/           GUI projects only: who uses the app
docs/mockups/index.html     GUI projects only: the v1 mockup you approved
.github/workflows/       CI that sets up prerequisites, then runs the same gate
```

On an empty repo it also writes a **walking skeleton**: the minimum code that gives every
gate category something real to check, so the first pass means something.

### The gate

| category | checks |
|---|---|
| A | build, typecheck, lint |
| B | tests |
| B2 | boots the real artifact and probes it (server: liveness route; CLI: smoke run; library: import) |
| C | one grep per mechanically checkable rule |
| D | the workflow files, role contracts and generated agents are in sync |

Missing prerequisites (database down, no `.env`) **fail** the gate. Nothing is ever
skipped.

### Permission prompts

The harness runs a lot of shell commands. To keep them from stopping for approval
each time, init writes allow rules into the project's `.claude/settings.json`:

- One rule per harness script, e.g. `Bash(bash harness/validate.sh:*)`.
- Read-only git: `git status`, `git log`, `git diff`.
- Your stack's own commands (build, test, lint, run) and `scripts/init.sh` if it exists.

Claude Code asks you before it writes the file, and you can review the rules in your
sign-off. Things to know:

- A rule matches one exact command text. The harness always runs scripts as
  `bash harness/<script>.sh` from the repo root, one command at a time, because a
  chained or piped command (`cd … &&`, `| tail`) needs every part allowed separately.
- Project rules only apply after you trust the folder.
- If your organization's managed settings use `allowManagedPermissionRulesOnly`,
  project rules are ignored. Ask your admins to add the same rules to managed settings.

## Daily workflow

Start every session with `harness/skills/resume.md`. It checks git state, reads the task
board, and runs a baseline `validate.sh --no-boot`. Git and the board are the source of
truth, not chat memory.

Each piece of work is a task `T-00X`. You act as PM in the main session: write
`docs/tasks/T-00X/task.md`, and the track follows from fixed rules. Pick the simplest
track that fits; a task can move up a track, never down.

| track | when | stages |
|---|---|---|
| `solo` | trivial mechanical change: a typo, a rename, a log level | main session only; the full gate is the verdict |
| `fast` | **the default**: features and most bug fixes | spec → dev → review ∥ qa |
| `full` | new endpoint, schema change, migration, edit to SPEC/RULES, cross-package contract, new external dependency | design → dev → review ∥ qa |

On `fast` and `full`, the reviewer and QA run **in parallel**. A task is done only when
both pass; if either fails, it goes back to dev and both run again.

Examples:

- *T-004: users can export their trip history as CSV* → `fast`
- *T-007: add `POST /transfers` moving balance between two accounts* → `full` (new endpoint)
- *T-011: fix — refunds above the original charge are accepted* → `fast`. Write the
  failing test first; it is the acceptance criterion.

Bugs you notice mid-task are never fixed silently. They go into the board's *Bugs
spotted* section right away, then become a task or are deferred.

### The app boots once per task

Booting the artifact is the slow check, so each stage runs only what it needs:

| stage | command | categories |
|---|---|---|
| dev | `validate.sh --no-boot` | A, B, C, D |
| reviewer | `validate.sh --static` | A, C, D |
| QA | `validate.sh` | all, including B2 |

On `solo`, the main session runs the full gate.

## GUI projects: mockup first

For apps with a user interface, you shape the app in static HTML before anything
expensive to change exists.

**At init**, the interview also asks who uses the app. For a work-order app that might be
a *field technician* (phone, gloves, patchy signal), a *dispatcher* (desktop, many jobs at
once) and a *site contact* (opens an emailed link, approves work). Claude writes
`docs/personas/*.md`, then builds `docs/mockups/index.html` as those personas. You click
through it and ask for changes until you approve it. Only then are the acceptance
criteria drafted, SPEC frozen, and the stack installed.

**On every task that adds or changes a screen or flow:**

```
persona → mockup → (you approve) → spec → dev → review ∥ qa
```

- The PM names the persona(s) in `task.md`.
- The `ux-designer` builds `docs/tasks/T-00X/mockup.html` as that persona: one
  self-contained HTML file, clickable screen to screen, at the persona's viewport, with
  real copy and the error, empty and offline states.
- `check-mockup.sh` fails the mockup if it loads anything external or a screen can't be
  reached.
- No spec, design or code is written until you approve.
- Every acceptance criterion in the spec is tagged with the screens that show it
  (`AC-3 … [screen: signoff]`) or `[non-visual]`. The gate fails if one is untagged or a
  screen is left uncovered.
- QA later walks the real app through the same screens as the persona.

**Reviewing a mockup.** Each mockup has a review bar at the bottom: a screens list, a
persona switch, and ‹ n/N › navigation. Keys: `0` screens, `← →` step, `i` screen info,
`.` hide the bar. Clicking something that isn't wired highlights what is. Headless
screenshots hide the bar unless the URL has `?bar`.

**Several personas.** The designer tags each screen with `data-personas="parent kid"`, and
`split-mockup.sh` generates one file per persona (`index-parent.html`, `index-kid.html`, …),
each starting on that persona's first screen at its viewport. `P` / `Shift+P` switch
between them. Only edit the combined file; the gate fails if a generated file is stale.

## Upgrading a harnessed project

A scaffold is a one-time copy, so later plugin releases don't reach a project by
themselves. Update the plugin:

```sh
claude plugin marketplace update cs4dev
claude plugin update harness@cs4dev     # then restart, or /reload-plugins
```

Then, inside the project:

```
/harness:init upgrade
```

What upgrade does:

- Refreshes only the generic machinery: `workflow.yaml`, the role contracts, the gate
  helper scripts and the mockup starter. It then regenerates `.claude/agents/`.
- Keeps your local edits to those files. It never touches SPEC, RULES or
  `validate.sh`.
- Re-runs the gate and leaves one diff for you to review and commit.
- Needs a clean git tree.

Each scaffold records its plugin release (for example `v2.3.1`) in
`harness/workflow/.harness-version`. Upgrade fetches that release from GitHub and uses it
for a 3-way merge (`git merge-file`). If the stamp is missing or the release can't be
fetched (offline), it falls back to a 2-way diff that it walks through with you.

To get releases automatically: `/plugin` → Marketplaces → cs4dev → Enable auto-update.
It is off by default for third-party marketplaces.

## Rules of thumb

- The gate will block real work. That is the point: fix the work, not the gate.
- B2 exists because "compiles" is not "runs".
- Downstream stages never edit upstream artifacts. Blockers go back through the PM.

See [skills/init/SKILL.md](skills/init/SKILL.md) for the full procedure.

## Contributing

Work from a clone and load it in place with `claude --plugin-dir .`, or
`/plugin marketplace add ./` (a local marketplace is used without a cache copy).

The repo follows its own rule: a change is done when `bash harness/validate.sh` exits 0.
The gate needs `python3` and the `claude` CLI (for `claude plugin validate`). It scaffolds
throwaway repos and checks `scaffold.sh` output, that `validate-workflow.sh` rejects
broken workflows, that the `validate.sh` template fails until it is filled in, and the
plugin manifests and version stamps. CI runs the same gate on Linux and macOS.

**Releases.** Plugin users only get an update when `version` in
`.claude-plugin/plugin.json` changes. The gate fails if shipped files (`skills/`,
`assets/`, `scripts/`, `references/`) changed since the current version's tag, so any
change to them needs a version bump. On merge to main, CI tags `v<version>`; that tag is
what scaffolds record and what upgrade fetches.
