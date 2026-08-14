---
name: pre-push-checklist
description: Run verification before commit or PR in any project. Use when finishing a task, before pushing, or when the user asks if changes are ready to merge.
---

# Pre-push checklist (generic)

Run from **repo root** (`git rev-parse --show-toplevel`).

## 1. Scope review

- [ ] Diff matches the user request only (see `/skill:minimal-diff`)
- [ ] No secrets, live `.env` files, tokens, or PEMs staged
- [ ] No accidental `dist/`, `target/`, `node_modules/`, `.venv/` commits

## 2. Layer-specific tests

Run what your change touched. Discover commands from README, `package.json` scripts, CI (`.github/workflows/`), or `Makefile`.

### Common patterns

| Stack | Typical verify |
|-------|----------------|
| Rust | `cargo test`, `cargo clippy` |
| Node / TS | `npm test`, `npm run build`, `npm run lint` |
| Python | `pytest`, `ruff check`, `mypy` |
| Go | `go test ./...`, `go vet ./...` |
| Docker / compose | `docker compose config`, smoke script if documented |

If unsure, read CI config for the canonical commands.

## 3. Security-sensitive changes

If auth, uploads, payments, crypto, or admin routes:

- Re-read project `SECURITY.md` or security section in README
- Confirm secrets stay out of logs and commits
- Check new endpoints for authz, not just authn

## 4. Report to user

1. What you changed (files + why)
2. Which commands you ran and pass/fail
3. What you did **not** run (and why — e.g. no local DB)
4. Any manual steps the user should do before merge
