# context — {{PROJECT_NAME}}

> ~30-line digest every sub-agent reads FIRST instead of the full SPEC/RULES.
> Open SPEC.md / RULES.md in full only where the task touches them.

## Commands
build `{{BUILD_CMD}}` · test `{{TEST_CMD}}` · run `{{RUN_CMD}}` · gate `bash harness/validate.sh` (`--no-boot` dev, `--static` review, full = QA/solo)

## Frozen rules (one-liners — full text in RULES.md)
(R1 done = gate exits 0; R2 SPEC is law; + the domain rules, one line each)

## File map (top level only — detail in docs/dev-map.md)
(where server/client/shared/tests live, one line each)
