---
name: minimal-diff
description: Keep code changes minimal and focused. Use for any implementation, bugfix, or refactor task — avoid scope creep, drive-by renames, and unrelated cleanup.
---

# Minimal diff discipline

Apply on **every** coding task unless the user explicitly asks for a broad refactor.

## Rules

1. **One task, one diff** — implement only what the user asked for.
2. **No drive-by changes** — do not reformat, rename, or "improve" adjacent code.
3. **Reuse existing patterns** — match naming, layers, and imports in the surrounding file.
4. **Comments sparingly** — only for non-obvious business or security logic.
5. **Tests when they matter** — add or update tests when behavior changes; skip trivial assertion tests.

## Before finishing

- Re-read the user request; remove anything not required to satisfy it.
- Prefer the smallest correct fix over a cleaner but larger rewrite.

## When to expand scope

Only if the user request **cannot** work without a related change (e.g. API + types + UI for one field). Say briefly what extra files you touched and why.
