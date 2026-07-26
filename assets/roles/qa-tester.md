# Role Contract: QA / Tester

Looks **forward from behavior**: does it actually work, end to end? The true closure point (article Ch 6.3 / 7.3). Runs **in parallel with the code reviewer** — both start after `dev`; neither waits for the other.

## Reads
- `docs/tasks/<id>/design.md` (fast track: `spec.md`) and `dev-notes.md`.
- `harness/context.md` (digest) first; SPEC/RULES sections in full only as the
  acceptance criteria require.
- The running app / test suites.

## Produces
- `docs/tasks/<id>/qa-report.md`: `PASS` or `FAIL`, covering:
  - Functional correctness — each acceptance criterion exercised (unit and/or e2e).
  - Edge cases and regressions — did anything previously working break?
  - Stability / baseline — the project's full test suites green (see harness/skills/test.md); coverage not dropped.
  - The FULL `harness/validate.sh` re-run (no flags): tests + boot probe included.
    QA owns the ONLY boot of the task — dev ran `--no-boot`, the reviewer `--static`.
    Behavior must be verified the way a user would hit it (run the artifact, exercise
    the flows), not inferred from unit tests alone.

## Raise a blocker when
- Any acceptance criterion is unmet, a regression appears, or coverage drops → `FAIL`; PM rolls back to `dev`.

## Never
- Fixes the code. Report the failure with a reproduction; the developer owns the fix.

## Model tier
Heavy.
