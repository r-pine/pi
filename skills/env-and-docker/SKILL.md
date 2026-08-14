---
name: env-and-docker
description: Docker Compose, env files, and local stack setup for any project. Use when starting services, editing env vars, debugging containers, or deploying locally.
---

# Env and Docker (generic)

## Env file conventions

Many projects split env by target:

| File pattern | Typical use |
|--------------|-------------|
| `.env.example` / `.env.*.example` | Committed templates — safe to edit |
| `.env`, `.env.local`, `.envs/.env.*` | Live secrets — **gitignored**, never commit |
| `web/.env`, `admin/.env` | Local frontend dev only |
| `.envs/.env.front` | Docker build args for frontends |

**Rule:** copy from `*.example`, fill locally, never commit live values.

## Docker Compose workflow

```bash
# Validate compose files
docker compose config

# Start dependencies only (if split compose files exist)
docker compose -f docker-compose.db.yml up -d

# Full stack
docker compose up -d --build

# Logs
docker compose logs -f <service>

# Tear down
docker compose down
```

## Debugging containers

1. `docker compose ps` — which services are up
2. `docker compose logs <service>` — startup errors
3. Exec into service: `docker compose exec <service> sh`
4. Check **service names** in compose — use exact names from `docker-compose*.yml`, not guesses

## Common pitfalls

- Hostname in compose network ≠ `localhost` from inside containers
- Port published on host may differ from internal port
- Rebuild after Dockerfile or dependency changes: `docker compose up -d --build`
- Volume mounts may hide built artifacts — check bind mounts in compose

## Smoke / health checks

Look for project scripts:

```bash
./scripts/smoke-health.sh
./scripts/init-envs.sh
make smoke
```

If none exist, hit documented health URL or run the app's test suite against the running stack.

## Before changing deploy config

- Read `docs/DEPLOY.md`, `README.md`, or infra README
- Match existing service naming (avoid collisions with other stacks on shared hosts)
- Document new env vars in `*.example` files
