---
name: pi-feature-workflow
description: Multi-agent workflows for cross-layer features. Use when a task spans multiple parts of the codebase, or when the user asks for parallel agents or a workflow.
---

# Pi feature workflows (generic)

Requires package **`pi-extensible-workflows`** in `.pi/settings.json` (installed by default bootstrap).

Load skill **`pi-extensible-workflows`** (from the package) for runtime API: `parallel`, `pipeline`, `shell`, `workflow_retry`, `workflow_status`.

Inspect **`workflow_catalog`** at least once before first use.

## When to use workflows

| Situation | Approach |
|-----------|----------|
| Single file / single layer | Normal tools — **no workflow** |
| API + worker + UI same feature | `parallel` → integrator agent |
| Edit → verify → fix loop | `pipeline` with shell verification step |
| Security-sensitive | implementer → read-only reviewer |

## Pattern A — cross-layer feature

Replace `<REPO>`, `<DESCRIBE>`, and layer paths with project-specific values (use `/skill:monorepo-map` first).

```javascript
const REPO = "<absolute repo root>";

const layerWork = await parallel("feature-layers", {
  layerA: () => agent({
    label: "layer-a",
    prompt: `Implement layer A for: <DESCRIBE>.
    Run this project's tests for layer A.
    Repo: ${REPO}`,
    thinking: "medium",
  }),
  layerB: () => agent({
    label: "layer-b",
    prompt: `Implement layer B for: <DESCRIBE>.
    Run this project's tests for layer B.
    Repo: ${REPO}`,
    thinking: "medium",
  }),
});

return await agent({
  label: "integrator",
  prompt: `Integrate and verify this feature.

Layer A:
${layerWork.layerA}

Layer B:
${layerWork.layerB}

Check contract consistency. Run pre-push checks from skill pre-push-checklist.
Report what passed and what needs manual verification.`,
  thinking: "high",
});
```

Launch with `foreground: true` if the user waits for the result.

## Pattern B — verify gate

```javascript
const work = await agent({
  label: "implement",
  prompt: `<USER TASK>. Follow minimal-diff skill.`,
});

const verify = await shell("<project test command>", { cwd: REPO });

if (verify.exitCode !== 0) {
  return await agent({
    label: "fix",
    prompt: `Verification failed.

Work so far:
${work}

stdout: ${verify.stdout}
stderr: ${verify.stderr}

Fix and re-verify.`,
    retries: 1,
  });
}

return { ok: true, output: verify.stdout };
```

## Pattern C — read-only review

```javascript
const impl = await agent({
  label: "implement",
  prompt: `<USER TASK>. Follow minimal-diff.`,
});

return await agent({
  label: "review",
  tools: ["read", "grep", "find", "ls", "bash"],
  prompt: `Read-only review of this implementation:

${impl}

Use bash read-only only (git diff, cat). No writes.
List findings: OK / WARN / BLOCK.`,
  thinking: "high",
});
```

## Recovery

- `workflow_status({ runId })` before retry/resume
- `workflow_retry({ runId, expectedState })` after failure
- Use `shell()` for **verification only**, not mutations

## Skills to mention in agent prompts

- `monorepo-map` — navigation
- `env-and-docker` — if deploy-related
- `pre-push-checklist` — before declaring done
