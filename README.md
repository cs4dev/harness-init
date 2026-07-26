# harness-init

Claude Code skill that scaffolds a Level-3 Harness Engineering setup into any project:
frozen SPEC, RULES, role SOPs, a master validation gate, and a three-track multi-agent
workflow (solo / fast / full).

## Install

```sh
git clone https://github.com/cs4dev/harness-init.git ~/.claude/skills/harness-init
```

## Use

In Claude Code:

```
/harness-init web app, Fastify + React
```

Stack resolution: invocation argument → scan of an existing repo (detect, confirm) →
for empty repos, it recommends 2-3 stacks for you to pick. Commands, gate checks, and
SOPs derive from that, then a scope/correctness/acceptance interview.

See [SKILL.md](SKILL.md) for the full contract.
