#!/usr/bin/env bash
# Generate project-root AGENTS.md from deterministic repo scan + pi bootstrap context.
#
# Usage:
#   ./scripts/generate-agents-md.sh <project_root> <pi_dir>
#   PI_AGENTS_FORCE=1 ./scripts/generate-agents-md.sh ...   # overwrite existing

set -euo pipefail

_agents_warn() { printf 'warning: %s\n' "$*" >&2; }

_resolve_workspace_root() {
  local root="$1"
  local markers=(.gitignore package.json pyproject.toml Cargo.toml go.mod pom.xml composer.json Gemfile)
  local m
  for m in "${markers[@]}"; do
    [[ -f "$root/$m" ]] && { printf '%s\n' "$root"; return 0; }
  done
  local child name
  local -a children=()
  for child in "$root"/*; do
    [[ -d "$child" ]] || continue
    name="$(basename "$child")"
    [[ "$name" == .* ]] && continue
    [[ "$name" == "__MACOSX" ]] && continue
    children+=("$child")
  done
  if [[ ${#children[@]} -eq 1 ]]; then
    for m in "${markers[@]}"; do
      [[ -f "${children[0]}/$m" ]] && { printf '%s\n' "${children[0]}"; return 0; }
    done
  fi
  printf '%s\n' "$root"
}

_detect_stack_section() {
  local ws="$1"
  local -a markers=()
  local -a manifests=()
  local -a ci=()
  local pkg_mgr="" primary="unknown"

  [[ -f "$ws/package.json" ]] && { markers+=("node"); manifests+=("package.json"); }
  [[ -f "$ws/pnpm-workspace.yaml" || -f "$ws/pnpm-workspace.yml" ]] && markers+=("monorepo")
  [[ -f "$ws/turbo.json" || -f "$ws/nx.json" || -f "$ws/lerna.json" ]] && markers+=("monorepo")
  [[ -f "$ws/pyproject.toml" || -f "$ws/requirements.txt" || -f "$ws/Pipfile" || -f "$ws/setup.py" ]] \
    && { markers+=("python"); manifests+=("python-manifest"); }
  [[ -f "$ws/Cargo.toml" ]] && { markers+=("rust"); manifests+=("Cargo.toml"); }
  [[ -f "$ws/go.mod" ]] && { markers+=("go"); manifests+=("go.mod"); }
  [[ -f "$ws/pom.xml" || -f "$ws/build.gradle" || -f "$ws/build.gradle.kts" ]] \
    && { markers+=("java"); manifests+=("java-manifest"); }
  [[ -f "$ws/composer.json" ]] && { markers+=("php"); manifests+=("composer.json"); }
  [[ -f "$ws/Gemfile" ]] && { markers+=("ruby"); manifests+=("Gemfile"); }
  find "$ws" -maxdepth 1 -name 'Dockerfile*' -print -quit 2>/dev/null | grep -q . && markers+=("docker")
  [[ -f "$ws/docker-compose.yml" || -f "$ws/docker-compose.yaml" ]] && markers+=("docker")
  find "$ws" -maxdepth 1 -name 'docker-compose*.yml' -print -quit 2>/dev/null | grep -q . && markers+=("docker")
  [[ -d "$ws/.github/workflows" ]] && ci+=("github_actions")
  [[ -f "$ws/.gitlab-ci.yml" ]] && ci+=("gitlab_ci")

  if [[ -f "$ws/package-lock.json" ]]; then pkg_mgr="npm"
  elif [[ -f "$ws/pnpm-lock.yaml" ]]; then pkg_mgr="pnpm"
  elif [[ -f "$ws/yarn.lock" ]]; then pkg_mgr="yarn"
  elif [[ -f "$ws/bun.lockb" || -f "$ws/bun.lock" ]]; then pkg_mgr="bun"
  fi

  for candidate in node python rust go java php ruby docker monorepo; do
    local m
    for m in "${markers[@]}"; do
      [[ "$m" == "$candidate" ]] && { primary="$candidate"; break 2; }
    done
  done
  if [[ "$primary" == "unknown" && ${#markers[@]} -gt 0 ]]; then
    primary="${markers[0]}"
  fi

  STACK_PRIMARY="$primary"
  STACK_MARKERS="${markers[*]-}"
  STACK_MANIFESTS="${manifests[*]-}"
  STACK_CI="${ci[*]-}"
  STACK_PKG_MGR="$pkg_mgr"
}

_detect_commands_section() {
  local ws="$1"
  local -a lines=()
  COMMAND_LINES=()

  _append_pkg_scripts() {
    local dir="$1"
    local label="$2"
    local pkg="$dir/package.json"
    [[ -f "$pkg" ]] || return 0
    if command -v node >/dev/null 2>&1; then
      while IFS=$'\t' read -r script cmd; do
        [[ -n "$script" ]] || continue
        case "$script" in
          test|build|lint|dev|start|check|format|typecheck|ci)
            if [[ "$dir" == "$ws" ]]; then
              lines+=("${label:+$label }npm run $script")
            else
              local rel="${dir#"$ws"/}"
              lines+=("cd $rel && npm run $script")
            fi
            ;;
        esac
      done < <(node - "$pkg" <<'NODE'
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const scripts = pkg.scripts || {};
for (const [name, cmd] of Object.entries(scripts)) {
  process.stdout.write(name + "\t" + cmd + "\n");
}
NODE
)
    fi
  }

  _append_pkg_scripts "$ws" ""

  while IFS= read -r -d '' pkg; do
    local dir
    dir="$(dirname "$pkg")"
    [[ "$dir" == "$ws" ]] && continue
    _append_pkg_scripts "$dir" ""
  done < <(find "$ws" -maxdepth 3 -name package.json -not -path '*/node_modules/*' -not -path '*/.pi/*' -print0 2>/dev/null)

  if [[ -f "$ws/Cargo.toml" ]]; then
    lines+=("cargo test")
    lines+=("cargo build")
  fi
  while IFS= read -r -d '' cargo; do
    local dir
    dir="$(dirname "$cargo")"
    [[ "$dir" == "$ws" ]] && continue
    local rel="${dir#"$ws"/}"
    lines+=("cd $rel && cargo test")
  done < <(find "$ws" -maxdepth 3 -name Cargo.toml -not -path '*/target/*' -not -path '*/.pi/*' -print0 2>/dev/null)

  if [[ -f "$ws/Makefile" ]]; then
    for target in test build lint check; do
      if grep -qE "^${target}:" "$ws/Makefile" 2>/dev/null; then
        lines+=("make $target")
      fi
    done
  fi

  if [[ -f "$ws/pyproject.toml" || -f "$ws/requirements.txt" ]]; then
    lines+=("pytest")
  fi
  if [[ -f "$ws/go.mod" ]]; then
    lines+=("go test ./...")
  fi

  if [[ -f "$ws/docker-compose.yml" || -f "$ws/docker-compose.yaml" ]]; then
    lines+=("docker compose up -d --build")
  fi
  if [[ -f "$ws/docker-compose.und.yml" ]]; then
    lines+=("docker compose -f docker-compose.und.yml --env-file .env.understory up -d --build")
  fi

  COMMAND_LINES=()
  if [[ ${#lines[@]} -eq 0 ]]; then
    return 0
  fi
  local line seen
  for line in "${lines[@]}"; do
    seen=0
    local u
    for u in "${COMMAND_LINES[@]}"; do
      [[ "$u" == "$line" ]] && { seen=1; break; }
    done
    [[ "$seen" == 1 ]] || COMMAND_LINES+=("$line")
  done
}

_detect_layout_section() {
  local ws="$1"
  local -a rows=()
  local name

  _row() {
    rows+=("$1|$2")
  }

  for name in backend api server src web frontend admin app apps packages services; do
    [[ -d "$ws/$name" ]] || continue
    if [[ -f "$ws/$name/Cargo.toml" ]]; then
      _row "Rust / backend" "$name/"
    elif [[ -f "$ws/$name/package.json" ]]; then
      _row "Node / frontend or service" "$name/"
    elif [[ -f "$ws/$name/pyproject.toml" || -f "$ws/$name/requirements.txt" ]]; then
      _row "Python" "$name/"
    elif [[ -f "$ws/$name/go.mod" ]]; then
      _row "Go" "$name/"
    else
      _row "Project module" "$name/"
    fi
  done

  [[ -f "$ws/docker-compose.yml" || -f "$ws/docker-compose.yaml" || -f "$ws/docker-compose.und.yml" ]] \
    && _row "Docker / deploy" "docker-compose*.yml"

  LAYOUT_ROWS=("${rows[@]}")
}

_list_pi_skills() {
  local pi_dir="$1"
  local -a skills=()
  local s
  for s in "$pi_dir"/skills/*/SKILL.md; do
    [[ -f "$s" ]] || continue
    skills+=("$(basename "$(dirname "$s")")")
  done
  PI_SKILLS="${skills[*]-}"
}

_list_pi_packages() {
  local pi_dir="$1"
  PI_PACKAGES_LIST=""
  if command -v node >/dev/null 2>&1 && [[ -f "$pi_dir/settings.json" ]]; then
    PI_PACKAGES_LIST="$(node - "$pi_dir/settings.json" <<'NODE'
const fs = require("fs");
const s = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const pkgs = Array.isArray(s.packages) ? s.packages.filter(Boolean) : [];
process.stdout.write(pkgs.join(", ") || "(none)");
NODE
)"
  fi
}

generate_agents_md() {
  local project_root="$1"
  local pi_dir="$2"
  local out="$project_root/AGENTS.md"
  local ws
  ws="$(_resolve_workspace_root "$project_root")"

  if [[ -f "$out" && "${PI_AGENTS_FORCE:-}" != "1" ]]; then
    _agents_warn "AGENTS.md already exists at $out — skipping (set PI_AGENTS_FORCE=1 to overwrite)"
    return 0
  fi

  _detect_stack_section "$ws"
  _detect_commands_section "$ws"
  _detect_layout_section "$ws"
  _list_pi_skills "$pi_dir"
  _list_pi_packages "$pi_dir"

  local has_understory=0
  [[ -f "$pi_dir/skills/understory/SKILL.md" ]] && has_understory=1

  {
    cat <<EOF
# AGENTS.md

Quick reference for coding agents. Full rules: \`.pi/SYSTEM.md\`, \`README.md\`.
Auto-generated by pi bootstrap \`install.sh\` ($(date -u +%Y-%m-%d)).

## Repo root

Always \`cd\` to the project root first:

\`\`\`bash
cd $project_root
\`\`\`

EOF

    if [[ ${#LAYOUT_ROWS[@]} -gt 0 ]]; then
      echo "## Where to edit (auto-detected hints)"
      echo
      echo "| Task | Location |"
      echo "|------|----------|"
      local row task loc
      for row in "${LAYOUT_ROWS[@]}"; do
        task="${row%%|*}"
        loc="${row#*|}"
        echo "| $task | \`$loc\` |"
      done
      echo
      echo "_Refine this table for your domain — paths above are heuristic._"
      echo
    else
      cat <<'EOF'
## Where to edit — TODO

| Task | Location |
|------|----------|
| _describe modules_ | _paths_ |

EOF
    fi

    cat <<EOF
## Stack (auto-detected)

- Primary: \`${STACK_PRIMARY:-unknown}\`
EOF
    [[ -n "${STACK_MARKERS:-}" ]] && echo "- Markers: ${STACK_MARKERS}"
    [[ -n "${STACK_MANIFESTS:-}" ]] && echo "- Manifests: ${STACK_MANIFESTS}"
    [[ -n "${STACK_PKG_MGR:-}" ]] && echo "- Package manager: ${STACK_PKG_MGR}"
    [[ -n "${STACK_CI:-}" ]] && echo "- CI: ${STACK_CI}"
    [[ "$ws" != "$project_root" ]] && echo "- Note: workspace root resolved to \`${ws#$project_root/}\` (nested layout)"
    echo

    echo "## Common commands (auto-detected)"
    echo
    if [[ ${#COMMAND_LINES[@]} -gt 0 ]]; then
      echo '```bash'
      local cmd
      for cmd in "${COMMAND_LINES[@]}"; do
        echo "$cmd"
      done
      echo '```'
    else
      echo "_(no common commands detected — add manually)_"
    fi
    echo

    cat <<EOF
## Pi

First time: \`/trust\` in a pi session (loads \`.pi/settings.json\` and packages).

Project packages: ${PI_PACKAGES_LIST:-see .pi/settings.json}

Load skills with \`/skill:<name>\`:

| Skill | Use when |
|-------|----------|
| \`minimal-diff\` | Any code change — keep scope tight |
| \`monorepo-map\` | Finding files, repo layout |
| \`pre-push-checklist\` | Before commit / PR |
| \`env-and-docker\` | Compose, env files, local stack |
| \`pi-feature-workflow\` | Multi-layer features / workflows |
EOF

    if [[ "$has_understory" == 1 ]]; then
      cat <<'EOF'
| `understory` | Agent memory MCP (docker-compose.und.yml) |
EOF
    fi

    echo
    if [[ -n "${PI_SKILLS:-}" ]]; then
      echo "Skills installed in \`.pi/skills/\`: ${PI_SKILLS}"
      echo
    fi

    cat <<'EOF'
## Project context — TODO

_One paragraph: what this repo does, main users, critical constraints._

## Do not

- Commit live `.env`, `.env.*` with secrets, PEM files, or API keys
- Run destructive git commands unless the user explicitly asks
- Expand scope beyond the requested task (see `/skill:minimal-diff`)

EOF

    if [[ "$has_understory" == 1 ]]; then
      cat <<'EOF'
## Understory (agent memory)

- Configure `.env.understory` (LLM_API_BASE_URL, LLM_API_KEY, LLM_MODEL)
- Web UI: http://localhost:3800 · MCP: http://localhost:3800/mcp
- Load `/skill:understory` for ops

EOF
    fi

  } > "$out"

  printf '==> Created %s\n' "$out"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: $0 <project_root> <pi_dir>" >&2; exit 1; }
  generate_agents_md "$1" "$2"
fi
