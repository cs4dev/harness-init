---
name: harness-init
description: >
  Scaffold a Level-3 Harness Engineering setup into
  any project: frozen SPEC, RULES, skills/SOPs, master validation gate,
  three-track multi-agent workflow (solo: main session + gate, for trivial
  changes; fast — the DEFAULT: spec→dev→review∥qa; full — explicit triggers
  only: design→dev→review∥qa) with role contracts, a one-boot-per-task gate
  split, and a workflow-sync gate.
  Stack resolution: invocation argument (/harness-init web
  app, Fastify + React) → scan of an existing repo (detect, confirm) → for empty
  repos, RECOMMEND 2-3 stacks for the human to pick. Commands, gate checks, and
  SOPs derive from that, then the scope/correctness/acceptance interview. Use
  when the user says "harness this project", "set up a harness", "harness-first",
  or invokes /harness-init [project type + stack].
---

# harness-init — scaffold a Level-3 harness

## Invocation
`/harness-init [project type + tech stack]` — the argument is free text from the human,
e.g. `/harness-init web app, pnpm monorepo + Fastify + tRPC + React 19` or
`/harness-init CLI tool in Go`. It answers interview Q0 directly: derive commands,
B2 shape, gate greps, and SOPs from it (confirm the derivations in the interview
summary).

Q0 resolution order (first source that answers wins):
1. **The argument** — free text from the human, as above.
2. **The repo** — on an existing (non-empty) repo, SCAN for the stack: manifests
   (package.json/go.mod/Cargo.toml/pyproject…), workspace layout, lockfiles,
   docker-compose, CI configs, scripts. State the detected type + stack in one line
   and confirm; don't interview for what the code already answers. If the scan is
   ambiguous (mixed signals, monorepo of several stacks), ask — listing what was found.
3. **Recommend** — empty repo and no/partial argument: ask what the project is for
   (if not stated), then propose 2–3 fitting stacks via AskUserQuestion with a
   recommended default and one-line tradeoffs. The human picks.
The human always confirms the stack before anything frozen is generated — detect or
recommend, never silently decide.

Philosophy (non-negotiable): the HUMAN owns the harness, the AI writes production
code. The harness is the durable asset; it lives in git, not chat memory. A task is
done when `harness/validate.sh` exits 0 — never on a verbal claim. So: generate the
scaffold, but every frozen decision (SPEC scope, domain rules) comes from the USER —
interview, don't invent.

## Assets shipped with this skill
- `assets/workflow.yaml` — the three-track relay (solo / fast / full, parallel review+qa,
  one-boot budget), generic, use VERBATIM.
- `assets/roles/*.md` — 6 role contracts (pm, requirements-analyst, solution-architect,
  developer, code-reviewer, qa-tester), generic, use VERBATIM.
- `assets/validate-workflow.sh` — workflow↔contracts sync gate, generic, use VERBATIM (chmod +x).
- `assets/templates/` — RULES, SPEC, CLAUDE.md index, validate.sh skeleton, CI workflow
  (ci.yml.template → .github/workflows/harness-gate.yml), doc templates:
  instantiate by filling `{{PLACEHOLDERS}}`.

## Procedure

### 1. Survey the project
Detect stack, package layout, existing test/lint/typecheck commands, existing CLAUDE.md
(merge, don't clobber). On an existing repo this survey IS the Q0 stack answer
(pending one-line confirmation). For Q1–Q3 the survey only informs — never replaces —
the interview.

### 2. Interview the user (AskUserQuestion, don't guess)
Required answers before writing anything frozen:
0. **What & with what** — what KIND of project is this (web app, CLI, API service,
   library, mobile, …) and what tech stack? Resolve per the Invocation order:
   argument → repo scan (existing repo: detect, state in one line, confirm — don't
   re-ask what the code answers) → recommend 2–3 options with a default. Everything
   downstream — commands, B2 shape, gate greps, skills SOPs — derives from this
   answer. (feeds SPEC §1/§3, harness/skills, validate.sh)
1. **Scope** — what is v1? What is explicitly OUT? (feeds SPEC §2)
2. **Correctness core** — what data must never be corrupted? Who is the authority on
   what (server vs client)? What logic must exist exactly once, frozen where?
   (feeds SPEC §4 + the 2–4 domain RULES)
3. **Acceptance** — 10–15 binary criteria for v1 (draft them, get sign-off; feeds SPEC §8)
4. **Commands** — typecheck/lint/test/build/run if not detectable from the repo or
   derivable from the Q0 stack answer (then just confirm them in the summary).
   Adapt B2 to the project type from Q0: server → boot + liveness probe; CLI → run the
   binary with a smoke arg and assert exit 0 + expected output; library → build + import
   smoke test. B2 always proves "it runs", whatever running means for this artifact.

### 3. Generate, in order
1. `SPEC.md` from template — mark **FROZEN v1** with today's date only after user sign-off.
2. `RULES.md` from template — R1 (Definition of Done) + R2 (SPEC is law) + the
   interviewed domain rules + the STANDING CROSS-CUTTING rules that fit this stack
   (soft-delete-by-default when the project persists user data; standard landing +
   not-found pages when it has a web/GUI client — both shipped in the template, include
   only those that apply) + no-placeholder/config/logging/baseline/artifact-ownership.
   Renumber contiguously; keep it ~10 rules, lean red lines, not a style guide. Each
   standing rule that's mechanically checkable gets a matching Category-C grep (the
   template carries adaptable examples for soft-delete and landing/404).
3. `harness/skills/{resume,run,build,test,validate}.md` — short SOPs with the real
   commands (resume = start-of-session bootstrap from the doc templates: git state →
   task-board → baseline `--no-boot` gate; validate documents all three gate modes).
3b. `harness/context.md` from the doc templates — a ~30-line digest (commands,
   frozen-rule one-liners, file map) that every sub-agent reads FIRST; full SPEC/RULES
   only where the task touches them. Regenerate it whenever commands/rules/layout change.
3c. `scripts/init.sh` — CONDITIONAL: only when the Q0 stack has prerequisites to
   materialize (service containers, .env, migrations, codegen). One idempotent
   script: services up → `.env` from `.env.example` if absent → deps install →
   wait-until-ready → migrate. chmod +x. Skip entirely when setup is just an
   install (library, static frontend) — a wrapper around one command is noise.
   When generated: resume.md step 0 runs it, and CI's env/services blocks reuse it
   where CI-compatible — setup-as-code, written once, not re-derived per session.
4. `harness/validate.sh` from skeleton — wire Categories A (build/static), B (tests),
   B2 (boot the runnable artifact + liveness probe; fail-not-skip; kill+wait cleanup),
   C (one grep per mechanically-checkable rule), D (calls validate-workflow.sh).
   chmod +x. **Run it; it must pass on the clean scaffold before you claim done.**
   **Empty repo → walking skeleton.** The gate never skips, so an empty repo gets the
   MINIMUM code that makes every category judge something real: package/workspace
   manifests, a runnable entry (server: liveness route; CLI: smoke arg; library:
   importable module), at least one real test — ideally guarding part of the
   correctness core from interview Q2 (e.g. the frozen state machine + its tests) —
   and config files the C greps check. Nothing more: features stay tasks (T-001+),
   the skeleton just proves the gate's verdict is earned, not vacuous.
5. `harness/workflow/` — copy workflow.yaml + roles/ + validate-workflow.sh verbatim.
6. `docs/dev-map.md`, `docs/task-board.md` (empty board), `docs/tasks/` from doc templates.
7. `.github/workflows/harness-gate.yml` from ci.yml.template — CI defines NO checks of
   its own; it sets up the toolchain/services/env from the Q0 stack, then runs the same
   `bash harness/validate.sh`. Gate fails on missing prerequisites, so CI must provide
   them (service containers, generated .env). Skip this file only if the repo has no
   GitHub remote AND the user declines; otherwise generate it.
8. `CLAUDE.md` from template (merge with any existing content).
9. Suggest a git commit ("harness: Level-3 scaffold") — the user decides.

### 4. Teach the loop (tell the user, briefly)
- Every session starts with `harness/skills/resume.md`: git state → task-board →
  baseline `--no-boot` gate. The board and git are the truth, not chat memory.
- New feature = new task `T-00X`: PM (the main session) writes `docs/tasks/T-00X/task.md`,
  picks the SIMPLEST track that fits (mechanical rules in pm.md — solo for trivial
  mechanical changes, fast is the DEFAULT, full only on an explicit trigger;
  promote-never-demote), then routes one ISOLATED sub-agent per stage; each reads
  `harness/context.md` first plus its contract's inputs and writes its artifact.
  Downstream NEVER edits upstream — blockers roll back via the PM.
- After dev, spawn reviewer and QA IN PARALLEL (one message, two sub-agents). Done
  requires both verdicts; either failure rolls back to dev and both re-run.
- ONE boot per task: dev runs `validate.sh --no-boot`, reviewer `--static`, QA the
  FULL gate (the only boot). Solo track: the main session runs the full gate — there
  the gate is the verdict. No self-grading on fast/full.
- Discipline that keeps loops recoverable: ONE task active at a time; the board is
  append-only (update status, never delete/reorder); out-of-scope bugs get logged to
  the board's Bugs section the moment they're found (fix or defer as a task, never
  silently either); dev-notes record the WHY — the next session won't share this
  context window.
- The PM stamps start/end per stage in the routing log — tune the workflow from
  measurements, not vibes.
- The gate will block real work. That is the point. Fix the work, not the gate.

## Hard-won portability notes (bake into generated files where relevant)
- bash gates: `set -uo pipefail` WITHOUT `-e` (cleanup must run; track a fail flag).
- macOS/BSD grep/sed: `[[:space:]]`, never `\s`.
- scan() greps must exclude node_modules/dist/build/.vite.
- Gate checks FAIL when prerequisites are missing (DB down, .env absent) — never skip.
- B2 exists because "compiles" ≠ "runs": boot the actual artifact, probe, clean up children.
- Gate speed is iteration count: order checks cheapest-first; an A failure skips B/B2
  (noise on a broken build) but still runs the cheap C/D. Dev iterates on TARGETED
  tests (touched unit only) and runs the full `--no-boot` gate once at stage end.
