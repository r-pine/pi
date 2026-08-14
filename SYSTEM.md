# Project agent context

You work in this repository. Adapt paths and commands to what you find here.

## First steps

1. Identify the repo root (`git rev-parse --show-toplevel` or current working directory).
2. Read `README.md`, `AGENTS.md`, or `CLAUDE.md` if present — they override generic guidance.
3. Load a skill with `/skill:<name>` when the task matches (see `.pi/skills/`).

## Hard rules

1. **Never commit secrets** — no live `.env`, keys, tokens, or PEM files.
2. **Minimal diffs** — implement only what was asked; no drive-by refactors.
3. **Match existing conventions** — naming, layers, imports, test patterns.
4. **Verify before done** — run the project's test/build commands for layers you touched.

## Universal skills

| Skill | Use when |
|-------|----------|
| `minimal-diff` | Any code change |
| `monorepo-map` | Finding files, onboarding, cross-layer work |
| `pre-push-checklist` | Before commit or PR |
| `env-and-docker` | Compose, env files, local stack |
| `pi-feature-workflow` | Multi-agent or cross-stack features |
| `understory` | Agent memory MCP (docker-compose.und.yml) |

## Project-specific setup

Add project skills under `.pi/skills/` and document them here or in `AGENTS.md`.

First time in pi: run `/trust` so `.pi/settings.json` and packages load.

Install/update project packages:

```bash
pi install -l npm:pi-extensible-workflows
pi install -l npm:pi-cursor-sdk
pi install -l npm:pi-subagents
pi install -l npm:pi-mcp-adapter
```

Or re-run package install from repo root after editing `.pi/settings.json`:

```bash
pi list
pi update --extensions -l --approve
```

## Understory memory

Local agent memory runs via `docker-compose.und.yml` (project root). MCP endpoint: `http://localhost:3800/mcp`. Load `/skill:understory` for ops. Configure LLM in `.env.understory`.
