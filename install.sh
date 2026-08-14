#!/usr/bin/env bash
# Pi bootstrap installer — self-deletes after successful run.
#
# Usage (from target project root):
#   git clone <this-repo-url> pi
#   ./pi/install.sh              # interactive quiz
#   ./pi/install.sh --yes        # install everything, no prompts
#
# Result: ./.pi/ with selected settings, skills, packages; install.sh removed.

set -euo pipefail

PI_PACKAGES=(
  "npm:pi-extensible-workflows"
  "npm:pi-cursor-sdk"
  "npm:pi-subagents"
  "npm:pi-mcp-adapter"
)

UNDERSTORY_REPO="${UNDERSTORY_REPO:-https://github.com/mitagmio/understory.git}"

# Set by quiz or --yes / env (PI_INSTALL_YES=1)
INSTALL_PI_CLI=1
INSTALL_PKG_WORKFLOWS=1
INSTALL_PKG_CURSOR=1
INSTALL_PKG_SUBAGENTS=1
INSTALL_PKG_MCP=1
INSTALL_UNDERSTORY=1

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Interactive bootstrap for .pi/ + optional npm packages + Understory.

Options:
  -y, --yes       Install all components without prompts
  -h, --help      Show this help

Environment:
  PI_INSTALL_YES=1   Same as --yes

Non-interactive stdin (no TTY): defaults are used (all yes).
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) PI_INSTALL_YES=1 ;;
      -h|--help) usage; exit 0 ;;
      --phase2) return 0 ;;
      *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
  done
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "${PI_INSTALL_YES:-}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    [[ "$default" == "y" ]]
    return
  fi

  while true; do
    if [[ "$default" == "y" ]]; then
      printf '%s [Y/n] ' "$prompt"
    else
      printf '%s [y/N] ' "$prompt"
    fi
    read -r reply </dev/tty
    reply="${reply:-$default}"
    case "${reply,,}" in
      y|yes|д|да) return 0 ;;
      n|no|н|нет) return 1 ;;
      *) printf '  Введите y/да или n/нет.\n' ;;
    esac
  done
}

run_install_quiz() {
  if [[ "${PI_INSTALL_YES:-}" == "1" ]]; then
    INSTALL_PI_CLI=1
    INSTALL_PKG_WORKFLOWS=1
    INSTALL_PKG_CURSOR=1
    INSTALL_PKG_SUBAGENTS=1
    INSTALL_PKG_MCP=1
    INSTALL_UNDERSTORY=1
    log "Режим --yes: устанавливаем все компоненты"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log "Неинтерактивный режим (нет TTY): используем значения по умолчанию (всё да)"
    return 0
  fi

  printf '\n╔══════════════════════════════════════════════════╗\n'
  printf '║  Pi bootstrap — что установить?                    ║\n'
  printf '╚══════════════════════════════════════════════════╝\n\n'
  printf '  Базовая конфигурация .pi (settings, skills, SYSTEM.md) — всегда.\n\n'

  ask_yes_no "  1. Pi CLI глобально (npm, если ещё нет)?" y \
    && INSTALL_PI_CLI=1 || INSTALL_PI_CLI=0

  printf '\n  Pi npm-пакеты (project-local):\n'
  ask_yes_no "  2. pi-extensible-workflows (оркестрация workflow)?" y \
    && INSTALL_PKG_WORKFLOWS=1 || INSTALL_PKG_WORKFLOWS=0
  ask_yes_no "  3. pi-cursor-sdk (мост Cursor IDE)?" y \
    && INSTALL_PKG_CURSOR=1 || INSTALL_PKG_CURSOR=0
  ask_yes_no "  4. pi-subagents (субагенты)?" y \
    && INSTALL_PKG_SUBAGENTS=1 || INSTALL_PKG_SUBAGENTS=0
  ask_yes_no "  5. pi-mcp-adapter (MCP инструменты)?" y \
    && INSTALL_PKG_MCP=1 || INSTALL_PKG_MCP=0

  printf '\n  Agent memory:\n'
  ask_yes_no "  6. Understory (Docker + docker-compose.und.yml)?" y \
    && INSTALL_UNDERSTORY=1 || INSTALL_UNDERSTORY=0

  printf '\n── Итого ──\n'
  printf '  pi CLI:              %s\n' "$([[ "$INSTALL_PI_CLI" == 1 ]] && echo да || echo нет)"
  printf '  workflows:           %s\n' "$([[ "$INSTALL_PKG_WORKFLOWS" == 1 ]] && echo да || echo нет)"
  printf '  cursor-sdk:          %s\n' "$([[ "$INSTALL_PKG_CURSOR" == 1 ]] && echo да || echo нет)"
  printf '  subagents:           %s\n' "$([[ "$INSTALL_PKG_SUBAGENTS" == 1 ]] && echo да || echo нет)"
  printf '  mcp-adapter:         %s\n' "$([[ "$INSTALL_PKG_MCP" == 1 ]] && echo да || echo нет)"
  printf '  understory:          %s\n' "$([[ "$INSTALL_UNDERSTORY" == 1 ]] && echo да || echo нет)"
  printf '\n'

  if ! ask_yes_no "  Продолжить установку?" y; then
    die "Установка отменена пользователем."
  fi
}

write_choices_file() {
  local file="$1"
  cat > "$file" <<EOF
INSTALL_PI_CLI=$INSTALL_PI_CLI
INSTALL_PKG_WORKFLOWS=$INSTALL_PKG_WORKFLOWS
INSTALL_PKG_CURSOR=$INSTALL_PKG_CURSOR
INSTALL_PKG_SUBAGENTS=$INSTALL_PKG_SUBAGENTS
INSTALL_PKG_MCP=$INSTALL_PKG_MCP
INSTALL_UNDERSTORY=$INSTALL_UNDERSTORY
EOF
}

load_choices_file() {
  local file="$1"
  # shellcheck disable=SC1090
  source "$file"
}

selected_pi_packages() {
  local out=()
  [[ "$INSTALL_PKG_WORKFLOWS" == 1 ]] && out+=("npm:pi-extensible-workflows")
  [[ "$INSTALL_PKG_CURSOR" == 1 ]] && out+=("npm:pi-cursor-sdk")
  [[ "$INSTALL_PKG_SUBAGENTS" == 1 ]] && out+=("npm:pi-subagents")
  [[ "$INSTALL_PKG_MCP" == 1 ]] && out+=("npm:pi-mcp-adapter")
  printf '%s\n' "${out[@]}"
}

load_selected_packages() {
  packages=()
  local listing
  listing="$(selected_pi_packages)" || return 0
  [[ -z "$listing" ]] && return 0
  mapfile -t packages <<< "$listing"
}

update_settings_json() {
  local settings_file="$1"
  shift
  local packages=("$@")

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found — settings.json packages not trimmed; edit manually if needed"
    return 0
  fi

  node - "$settings_file" "${packages[@]}" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const packages = process.argv.slice(3);
const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
settings.packages = packages;
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
NODE
}

prune_skipped_components() {
  local target_dir="$1"

  if [[ "$INSTALL_UNDERSTORY" != 1 ]]; then
    rm -rf "$target_dir/skills/understory"
    rm -f "$target_dir/docker-compose.und.yml" "$target_dir/.env.understory.example"
  fi
}

docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    die "docker compose not found. Install Docker with the Compose plugin (https://get.docker.com/)."
  fi
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    log "Docker found: $(docker --version 2>/dev/null || echo ok)"
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    warn "Docker CLI present but daemon not reachable; trying to start..."
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl start docker 2>/dev/null || true
    fi
    if docker info >/dev/null 2>&1; then
      log "Docker daemon started"
      return 0
    fi
  fi

  log "Docker not available. Installing via https://get.docker.com/ ..."
  if [[ $(id -u) -eq 0 ]]; then
    curl -fsSL https://get.docker.com/ | sh
  elif command -v sudo >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com/ | sudo sh
  else
    die "Docker not installed and no sudo access. Install Docker manually: https://get.docker.com/"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now docker 2>/dev/null || true
  fi

  if getent group docker >/dev/null 2>&1 && [[ $(id -u) -ne 0 ]]; then
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    warn "Added $USER to docker group. You may need to log out/in for group membership."
  fi

  if ! docker info >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
      warn "Docker works with sudo only. Consider re-login after usermod -aG docker."
    else
      die "Docker installed but daemon not reachable. Start docker and re-run understory setup."
    fi
  fi

  log "Docker installed: $(docker --version 2>/dev/null || echo ok)"
}

setup_understory() {
  local target_dir="$1"
  local project_root="$2"

  log "Setting up Understory (agent memory)..."

  ensure_docker

  local understory_src="$target_dir/understory"
  if [[ -d "$understory_src/.git" ]] || [[ -f "$understory_src/Dockerfile" ]]; then
    warn "Understory source already present at $understory_src — skipping clone"
  else
    log "Cloning $UNDERSTORY_REPO (shallow)..."
    git clone --depth 1 "$UNDERSTORY_REPO" "$understory_src"
    rm -rf "$understory_src/.git"
  fi

  local memory_dir="$target_dir/understory-memory"
  mkdir -p "$memory_dir"
  if [[ -z "$(ls -A "$memory_dir" 2>/dev/null)" ]] && [[ -d "$understory_src/sample-bundle" ]]; then
    log "Seeding memory bundle from sample-bundle..."
    cp -a "$understory_src/sample-bundle/." "$memory_dir/"
  fi

  local compose_src="$target_dir/docker-compose.und.yml"
  local compose_dst="$project_root/docker-compose.und.yml"
  if [[ -f "$compose_src" ]]; then
    cp "$compose_src" "$compose_dst"
  else
    die "docker-compose.und.yml missing in bootstrap template"
  fi

  local env_example_src="$target_dir/.env.understory.example"
  local env_example_dst="$project_root/.env.understory.example"
  local env_dst="$project_root/.env.understory"
  if [[ -f "$env_example_src" ]]; then
    cp "$env_example_src" "$env_example_dst"
  fi
  if [[ ! -f "$env_dst" ]] && [[ -f "$env_example_dst" ]]; then
    cp "$env_example_dst" "$env_dst"
    log "Created $env_dst — set LLM_API_* before using memory tools"
  fi

  ensure_project_gitignore "$project_root" ".env.understory"

  log "Building and starting Understory..."
  (
    cd "$project_root"
    if docker info >/dev/null 2>&1; then
      docker_compose -f docker-compose.und.yml --env-file .env.understory up -d --build
    else
      sudo docker_compose -f docker-compose.und.yml --env-file .env.understory up -d --build
    fi
  ) || warn "Understory compose failed — check .env.understory (LLM_API_BASE_URL, LLM_API_KEY, LLM_MODEL) and re-run: docker compose -f docker-compose.und.yml --env-file .env.understory up -d --build"

  local port="${UNDERSTORY_PORT:-3800}"
  if [[ -f "$env_dst" ]]; then
    port="$(grep -E '^UNDERSTORY_PORT=' "$env_dst" 2>/dev/null | cut -d= -f2- | tr -d ' "' || true)"
    port="${port:-3800}"
  fi
  log "Understory UI/MCP: http://localhost:${port} (MCP: /mcp)"
}

ensure_project_gitignore() {
  local project_root="$1"
  local line="$2"
  local gitignore="$project_root/.gitignore"
  if [[ -f "$gitignore" ]] && grep -qxF "$line" "$gitignore" 2>/dev/null; then
    return 0
  fi
  if [[ -f "$gitignore" ]]; then
    printf '\n# pi bootstrap\n%s\n' "$line" >> "$gitignore"
  fi
}

ensure_pi_cli() {
  if [[ "$INSTALL_PI_CLI" != 1 ]]; then
    if ! command -v pi >/dev/null 2>&1; then
      local pkg_count
      pkg_count="$(selected_pi_packages | wc -l)"
      if [[ "$pkg_count" -gt 0 ]]; then
        die "pi CLI не выбран для установки, но выбраны npm-пакеты. Установите pi или включите пункт 1 в квизе."
      fi
    else
      log "pi CLI: пропуск установки (выбор пользователя), найден: $(pi --version 2>/dev/null || echo ok)"
    fi
    return 0
  fi

  if command -v pi >/dev/null 2>&1; then
    log "pi CLI found: $(pi --version 2>/dev/null || echo unknown)"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    die "pi not found and npm is unavailable. Install Node.js/npm first, then re-run."
  fi

  log "Installing pi CLI globally via npm..."
  npm install -g @earendil-works/pi-coding-agent

  if ! command -v pi >/dev/null 2>&1; then
    local npm_bin
    npm_bin="$(npm prefix -g 2>/dev/null)/bin"
    if [[ -x "$npm_bin/pi" ]]; then
      export PATH="$npm_bin:$PATH"
    fi
  fi

  command -v pi >/dev/null 2>&1 || die "pi install finished but 'pi' is not on PATH. Add npm global bin to PATH and re-run."
  log "pi CLI installed: $(pi --version 2>/dev/null || echo ok)"
}

install_packages() {
  local project_root="$1"
  local -a packages=()
  load_selected_packages

  if [[ ${#packages[@]} -eq 0 ]]; then
    log "Pi npm-пакеты: пропуск (ничего не выбрано)"
    return 0
  fi

  command -v pi >/dev/null 2>&1 || die "pi CLI required for npm packages but not found"

  cd "$project_root"

  for pkg in "${packages[@]}"; do
    log "Installing package: $pkg"
    if pi install -l "$pkg" --approve 2>/dev/null; then
      continue
    fi
    pi install -l "$pkg" --no-approve
  done

  log "Installed packages:"
  pi list --approve 2>/dev/null || pi list 2>/dev/null || true
}

print_summary() {
  local project_root="$1"
  local target_dir="$2"

  cat <<EOF

Pi bootstrap complete.

  Project root: $project_root
  Config dir:     $target_dir

Next steps:
  1. cd $project_root
EOF

  if [[ "$INSTALL_UNDERSTORY" == 1 ]]; then
    cat <<EOF
  2. Edit .env.understory — set LLM_API_BASE_URL, LLM_API_KEY, LLM_MODEL
  3. Run: pi
  4. In pi session: /trust   (trust project .pi/settings.json)
  5. Understory: http://localhost:3800  MCP: http://localhost:3800/mcp
EOF
  else
    cat <<EOF
  2. Run: pi
  3. In pi session: /trust   (trust project .pi/settings.json)
EOF
  fi

  cat <<EOF
  • AGENTS.md created in project root (or already present — not overwritten)
  • Optional: add project-specific skills under .pi/skills/
  • Re-generate: PI_AGENTS_FORCE=1 bash .pi/scripts/generate-agents-md.sh "\$PWD" .pi

Skills in .pi/skills/: $(ls -1 "$target_dir/skills" 2>/dev/null | tr '\n' ' ' || echo —)
EOF

  if [[ "$INSTALL_UNDERSTORY" == 1 ]]; then
    cat <<EOF

Understory stack:
  docker compose -f docker-compose.und.yml --env-file .env.understory ps
  docker compose -f docker-compose.und.yml --env-file .env.understory logs -f understory
EOF
  fi
}

phase2_install() {
  local target_dir="$1"
  local project_root="$2"
  local installer_copy="$3"
  local choices_file="$4"

  load_choices_file "$choices_file"
  rm -f "$choices_file"

  log "Phase 2: finishing setup in $target_dir"

  rm -rf "$target_dir/.git"
  prune_skipped_components "$target_dir"

  local -a packages=()
  load_selected_packages
  update_settings_json "$target_dir/settings.json" "${packages[@]}"

  if [[ ${#packages[@]} -gt 0 ]] && [[ -f "$target_dir/npm/package.json" ]]; then
    log "Running npm install in .pi/npm (optional lockfile)..."
    (cd "$target_dir/npm" && npm install --omit=dev 2>/dev/null) || warn "npm install in .pi/npm skipped or failed (pi install handles packages)"
  fi

  install_packages "$project_root"

  if [[ "$INSTALL_UNDERSTORY" == 1 ]]; then
    setup_understory "$target_dir" "$project_root"
  else
    log "Understory: пропуск (выбор пользователя)"
  fi

  local agents_generator="$target_dir/scripts/generate-agents-md.sh"
  if [[ -f "$agents_generator" ]]; then
    log "Generating AGENTS.md in project root..."
    bash "$agents_generator" "$project_root" "$target_dir" \
      || warn "AGENTS.md generation failed — create manually or run: bash .pi/scripts/generate-agents-md.sh \"\$PWD\" .pi"
  else
    warn "scripts/generate-agents-md.sh not found — AGENTS.md not created"
  fi

  rm -f "$target_dir/install.sh"
  rm -f "$target_dir/docker-compose.und.yml"
  rm -f "$target_dir/.env.understory.example"
  rm -f "$installer_copy"

  log "Done."
  print_summary "$project_root" "$target_dir"
}

main() {
  # Phase 2 must not re-parse consumer flags
  if [[ "${1:-}" == "--phase2" ]]; then
    phase2_install "${3:?missing .pi dir}" "${2:?missing project root}" "${4:?}" "${5:?}"
    return 0
  fi

  parse_args "$@"

  local script_path
  script_path="$(readlink -f "${BASH_SOURCE[0]}")"
  local source_dir
  source_dir="$(dirname "$script_path")"
  local base_name
  base_name="$(basename "$source_dir")"
  local project_root
  project_root="$(dirname "$source_dir")"

  if [[ "$base_name" == ".pi" ]]; then
    die "Already installed as .pi/. Re-run is not supported."
  fi

  if [[ -d "$project_root/.pi" ]]; then
    die "$project_root/.pi already exists. Remove or merge manually before installing."
  fi

  if [[ ! -f "$source_dir/settings.json" ]]; then
    die "settings.json not found in $source_dir — is this the pi bootstrap repo?"
  fi

  log "Project root: $project_root"
  log "Bootstrap source: $source_dir"

  run_install_quiz

  local choices_file="/tmp/pi-install-choices-$$"
  write_choices_file "$choices_file"

  ensure_pi_cli

  local installer_copy="/tmp/pi-install-$$.sh"
  cp "$script_path" "$installer_copy"
  chmod +x "$installer_copy"

  log "Renaming $source_dir -> $project_root/.pi"
  mv "$source_dir" "$project_root/.pi"

  log "Phase 2: installing selected components (re-exec from temp copy)..."
  exec "$installer_copy" --phase2 "$project_root" "$project_root/.pi" "$installer_copy" "$choices_file"
}

main "$@"
