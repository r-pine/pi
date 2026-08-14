---
name: understory
description: Project agent memory via Understory MCP. Use when persisting facts across sessions, querying project knowledge, or wiring pi to the local memory server.
---

# Understory memory

Understory runs via `docker-compose.und.yml` at the project root (installed by pi bootstrap).

## Endpoints

| URL | Purpose |
|-----|---------|
| http://localhost:3800 | Web UI (browse graph, chat) |
| http://localhost:3800/mcp | MCP streamable HTTP |

Default port: `3800` (override with `UNDERSTORY_PORT` in `.env.understory`).

## Manage stack

From **project root**:

```bash
docker compose -f docker-compose.und.yml --env-file .env.understory up -d
docker compose -f docker-compose.und.yml --env-file .env.understory ps
docker compose -f docker-compose.und.yml --env-file .env.understory logs -f understory
docker compose -f docker-compose.und.yml --env-file .env.understory down
```

## MCP tools

When connected, agents get: `memory_query`, `memory_add`, `memory_update`, `memory_status`, `memory_maintain`.

Register in pi via `pi-mcp-adapter` or Cursor MCP settings pointing at `http://localhost:3800/mcp`.

If `AUTH_TOKEN` is set in `.env.understory`, send header `Authorization: Bearer <token>`.

## Memory files

Plain markdown OKF bundle lives at `.pi/understory-memory/` — readable, diffable, committable if desired.

## Config

Edit `.env.understory` (from `.env.understory.example`). Requires `LLM_API_BASE_URL`, `LLM_API_KEY`, and usually `LLM_MODEL`.

After env changes:

```bash
docker compose -f docker-compose.und.yml --env-file .env.understory up -d --build
```
