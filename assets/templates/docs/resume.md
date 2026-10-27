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
