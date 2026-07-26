# Doc templates (instantiate under docs/)

## docs/dev-map.md
```markdown
# dev-map — {{PROJECT_NAME}}

> Navigation chart. **Read before writing code** (RULES R5-equivalent). Check feature
> landing points + impact here first, then open the files. Maintained by whoever changes the code.

## Top-level layout
(annotated tree: SPEC/RULES/CLAUDE/harness/docs + source roots)

## Where things live
(one subsection per module: what it owns, the do-not-duplicate warnings)

## Conventions
(how to add a procedure/endpoint, where schemas go, "run `bash harness/validate.sh` before claiming done")
```

## docs/task-board.md
```markdown
# Task Board — {{PROJECT_NAME}}

> Requirement-side registry. Active tasks, current stage, linked docs, delivery conclusions.
> Maintained by the PM. **Append-only**: never remove or reorder entries — only update
> stage/status. ONE task active at a time.

## Tracks
`solo: dev(gate) → done` · `fast: spec → dev → review∥qa → done` · `full: design → dev → review∥qa → done`

## Active
_None._

## Bugs spotted (not yet tasks)
<!-- Any role that finds an out-of-scope bug logs it here IMMEDIATELY (via the PM),
     then keeps working its task. Each entry graduates to a T-00X or gets closed. -->
_None._

## Done
(per task: Stage / Delivered / Artifacts docs/tasks/<id>/ / Lesson captured)
```

## docs/tasks/<id>/task.md  (created by PM when a task starts)
```markdown
# T-00X — <title>

**Raw request:** <verbatim user ask + owner decisions already made>

**Track:** <solo|fast|full> — <the mechanical trigger that justified it>

**Workflow:** `harness/workflow/workflow.yaml` · **Artifacts:** this folder.

## PM routing log
<!-- Start/End per stage: workflow tuning needs measurements, not vibes. -->
| # | Stage | Agent | Start | End | Verdict | Note |
|---|-------|-------|-------|-----|---------|------|
```

## harness/context.md  (regenerate when commands/rules/layout change)
```markdown
# context — {{PROJECT_NAME}}

> ~30-line digest every sub-agent reads FIRST instead of the full SPEC/RULES.
> Open SPEC.md / RULES.md in full only where the task touches them.

## Commands
build `{{BUILD_CMD}}` · test `{{TEST_CMD}}` · run `{{RUN_CMD}}` · gate `bash harness/validate.sh` (`--no-boot` dev, `--static` review, full = QA/solo)

## Frozen rules (one-liners — full text in RULES.md)
(R1 done = gate exits 0; R2 SPEC is law; + the domain rules, one line each)

## File map (top level only — detail in docs/dev-map.md)
(where server/client/shared/tests live, one line each)
```

## harness/skills/resume.md  (session bootstrap SOP)
```markdown
# resume — start-of-session bootstrap

Run ONCE when a session starts on this repo, before picking up any task:
0. `[ -x scripts/init.sh ] && bash scripts/init.sh` — services/env/deps up before
   anything probes them. (Only exists when the stack has prerequisites; don't
   re-derive setup by trial and error — fix init.sh if it's wrong.)
1. `git status` + `git log --oneline -10` — know the state you inherited.
2. Read `docs/task-board.md` — active task + stage, or next planned task.
3. `bash harness/validate.sh --no-boot` — verify the baseline is green BEFORE new
   work; if it fails, fixing the baseline IS the first task (log it).
4. Resume from the task's routing log in `docs/tasks/<id>/task.md`.

Work ONE task per session: the active task, or the highest-priority planned one.
Finish (or cleanly park, with the routing log current) before starting another.
Never re-derive project state from chat memory — the board and git are the truth.
```
