---
name: monorepo-map
description: Navigate any repository layout. Use when finding where code lives, planning cross-layer features, or onboarding to an unfamiliar project.
---

# Repository map (generic)

Discover structure before editing. Do not assume a fixed stack.

## Discovery checklist

1. **Repo root** — `git rev-parse --show-toplevel` or walk up to find `.git`.
2. **Top-level dirs** — `ls` at root; note `backend/`, `frontend/`, `web/`, `api/`, `packages/`, `apps/`, `services/`, `infra/`, `docs/`.
3. **Manifest files** — `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `docker-compose*.yml`, `Makefile`.
4. **Agent docs** — `README.md`, `AGENTS.md`, `CLAUDE.md`, `.pi/SYSTEM.md`, `docs/`.
5. **Test entrypoints** — `npm test`, `cargo test`, `pytest`, `go test ./...` (read README or CI config).

## Layer → task routing (adapt to project)

| Change type | Usually start here |
|-------------|-------------------|
| HTTP / REST API | `api/`, `backend/`, `server/src/routes/` |
| DB schema | `migrations/`, `prisma/`, `alembic/` |
| Background jobs | `worker/`, `jobs/`, `queue/` |
| Web UI | `web/`, `frontend/`, `apps/web/` |
| Admin UI | `admin/`, `apps/admin/` |
| Shared types | `packages/`, `lib/`, `common/` |
| Infra / deploy | `docker-compose*.yml`, `infra/`, `deploy/`, `.envs/` |
| Config / secrets | `*.example` env files only in git — never live keys |

## Cross-stack features

When a feature spans layers:

1. Map the data contract first (API shape, events, DB fields).
2. Implement backend → worker/consumer → UI (or parallel with clear interfaces).
3. Use `/skill:pi-feature-workflow` for coordinated multi-agent work.
4. Run `/skill:pre-push-checklist` before declaring done.

## Document findings

After exploration, note for the user:

- Repo root path
- Relevant directories for this task
- Commands to build/test affected layers
