# RULES — {{PROJECT_NAME}} Harness

> Foundational constraints for any AI (or human) writing code in this repo.
> Rules are the **bottom line**, not a tutorial. They say *what must never be violated*.
> *How* to do fixed actions lives in Skills (`harness/skills/`). *Whether* the work passes lives in the validation script (`harness/validate.sh`).
> Rules are soft constraints — the validation script is the hard gate. When a rule is mechanically checkable, it is also enforced there.

## R1 — Definition of Done (the core gate)
A task is **not complete** on a claim of "done". It is complete only when, in order:
1. {{TYPECHECK_CMD}} exits 0.
2. {{LINT_CMD}} exits 0, zero warnings.
3. {{TEST_CMD}} passes 100%, zero skipped.
4. `harness/validate.sh` exits 0.
You may not report completion before all four pass. "I believe it's fine" is not completion.

## R2 — SPEC is law
`SPEC.md` (FROZEN v1) defines scope. Do not build anything outside SPEC §2. Do not silently reinterpret it. A change to behavior requires a new SPEC version, not an edit-in-place during implementation.

<!-- R3..R(N-4): DOMAIN RULES. 2–4 rules specific to this project's correctness core.
     Proven pattern: "money is integers, never floats", "server is the
     authority on X, client values never trusted", "algorithm Y is frozen,
     implemented once in <module>, never duplicated". Ask the user: what data
     must never be corrupted? who is the authority on what? what logic must
     exist exactly once? -->
{{DOMAIN_RULES}}

<!-- STANDING CROSS-CUTTING RULES — include each only when it applies to this stack,
     then renumber contiguously with the rest. They are conventions every project of
     that shape should inherit, independent of the domain. -->

<!-- INCLUDE when the project persists user data (DB, store, files): -->
## R{{NSD}} — Deletion is soft by default
A feature that "deletes" user data **soft-deletes**: set a `deletedAt` (or equivalent
tombstone), exclude it from default reads, and expose a restore path. Never hard-delete
user data (`DELETE`/`deleteOne`/`deleteMany`/`destroy`/`drop`/`rm`) unless SPEC explicitly
mandates a purge — and then that call carries a `// hard-delete: SPEC §X` marker on its
line. "Delete" never means silent, unrecoverable data loss.

<!-- INCLUDE when the project has a web / GUI client with routing: -->
## R{{NLP}} — Standard landing + not-found pages
The client always registers a landing view at the root route and a catch-all not-found
view. An unknown route renders the not-found page — never a blank screen, crash, or
dead-end. New top-level pages are reachable from existing navigation, not orphaned.

## R{{N4}} — No placeholder implementations
No stubs, hardcoded demo returns, mocks-as-implementation, or `TODO: implement` bodies presented as complete. Agents bias toward minimal code that compiles; compiling is not implementing. A feature is built in full or reported as NOT done — R1 judges behavior, not compilation.

## R{{N3}} — No hardcoded config or secrets
No hardcoded secrets, connection strings, or magic numbers. Config comes from env ({{ENV_MECHANISM}}). No relative `.env` traversal from nested packages.

## R{{N2}} — Structured logging only
No bare print/console calls in production code. Use the project's structured logger ({{LOGGER}}). Errors wrap context.

## R{{N1}} — Baseline honesty
"This failure was already here" is not an automatic excuse. Capture a baseline (`harness/validate.sh` before changes), diff after. Any failure, warning, or violation **you introduce** must be fixed before R1 passes.

## R{{N0}} — Artifact ownership (multi-agent)
A downstream role does not edit an upstream artifact (SPEC, design doc, dev-map). If an upstream artifact is wrong, raise a blocker and route back via the PM. Every artifact has one owner.
