# Role Contract: Requirements Analyst

Fast-track only. Turns a bounded request into one condensed, testable spec. "What to
build" plus a where-it-lands note — small enough that no separate design stage is needed.

## Reads
- The raw user request (via `task.md`).
- `harness/context.md` (digest: commands, frozen-rule one-liners, file map) — read first;
  open `SPEC.md` in full only where the task touches it.
- `docs/task-board.md` (is this a continuation? prior decisions?).

## Produces
- `docs/tasks/<id>/spec.md`, containing:
  - Problem statement (one paragraph).
  - In-scope list and explicit out-of-scope list.
  - Acceptance criteria — each binary (pass/fail), no "should/can/optional" (RULES R2 discipline).
  - Boundary/edge cases.
  - "Where it lands" — files/modules, citing `docs/dev-map.md`, so the developer
    needs no separate design.
  - Whether this needs a `SPEC.md` version bump (and which sections).

## Raise a blocker when
- The request contradicts frozen `SPEC.md` and cannot be done without a SPEC change the user has not approved.

## Escalate to PM when
- The request is too ambiguous to write binary acceptance criteria.
- The change turns out to need real design work (new schema/endpoint, cross-cutting
  impact) — the PM promotes the task to the full track.

## Model tier
Medium — read-and-structure work; precise instruction following, no synthesis of new design.
