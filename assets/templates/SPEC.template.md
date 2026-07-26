# SPEC — {{PROJECT_NAME}} (v1, FROZEN {{DATE}})

> The only source of truth for scope + behavior. Changes require a version bump
> (v1 → v1.1 …) with the changed sections listed — never an edit-in-place during
> implementation (RULES R2).

## §1 Purpose
One paragraph: what this product is and for whom.

## §2 Scope (v1)
Exhaustive in-scope list. Explicit out-of-scope list. Anything not listed here does not get built.

## §3 Domain model
Entities, fields, units. Pin the dangerous representations explicitly (e.g. "money is integer minor units; floats forbidden").

## §4 Core behavior / algorithms
The correctness core, precise enough to implement without interpretation. Number the formulas. Mark frozen algorithms as FROZEN and name the single module that owns them.

## §5 API surface
Every procedure/endpoint: name, input, output, auth requirement, trust rules (what server recomputes / never trusts from the client).

## §6 Constraints
Currencies/locales/limits/categories — frozen enumerations live here.

## §7 Stack
Languages, frameworks, datastores. (Build tooling stays OUT of SPEC — it can change without a version bump.)

## §8 Acceptance criteria
Numbered, binary (pass/fail), each mappable to a test. 10–15 for a v1. The master gate (`harness/validate.sh`) is the final criterion.

## §9 Glossary
Terms a new agent would misread without definitions.
