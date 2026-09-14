#!/usr/bin/env bash
# Install all Xscriptor AI agents and skills for OpenCode.
#
# Sources (repos xscriptor-ai/agents + xscriptor-ai/skills):
#   agents repo:  181 specialized agents + 24 consolidated senior agents
#   skills repo:  3 project skills (xscriptor, devx, samurai), 18 senior skills, 8 commands
#
# Source resolution: sibling checkouts of the agents/skills repos, or
# XSCRIPTOR_AGENTS_DIR / XSCRIPTOR_SKILLS_DIR overrides. If not found, the
# repos are downloaded (XSCRIPTOR_REF, default main).
#
# Remote:
#   curl -fsSL https://raw.githubusercontent.com/xscriptor-ai/scripts/main/install-agents.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/xscriptor-ai/scripts/main/install-agents.sh | bash -s -- --project
#
# Local:
#   ./install-agents.sh                    # Everything (agents + senior + skills + commands)
#   ./install-agents.sh --agents           # Specialized agents only
#   ./install-agents.sh --senior           # Senior agents only
#   ./install-agents.sh --skills           # Skills only
#   ./install-agents.sh --commands         # Commands only
#   ./install-agents.sh --groups general   # Specific groups only
#   ./install-agents.sh --interactive      # Interactive selection
#   ./install-agents.sh --project          # Install in .opencode/ (current dir)
#   ./install-agents.sh --dry-run          # Preview only
set -euo pipefail

XSCRIPTOR_REF="${XSCRIPTOR_REF:-main}"

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]:-}" ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  REPO_DIR=""
fi
PARENT_DIR=""
[[ -n "$REPO_DIR" ]] && PARENT_DIR="$(cd "$REPO_DIR/.." && pwd)"

AGENTS_SRC=""
SENIOR_SRC=""
SKILLS_SRC=""
SENIOR_SKILLS_SRC=""
COMMANDS_SRC=""
TMP_DIR=""

detect_agents() {
  local base="$1"
  if [[ -d "$base/agents/agents" && -d "$base/agents/senior/agents" ]]; then
    AGENTS_SRC="$base/agents/agents"
    SENIOR_SRC="$base/agents/senior/agents"
  elif [[ -d "$base/agents/languages" && -d "$base/senior/agents" ]]; then
    AGENTS_SRC="$base/agents"
    SENIOR_SRC="$base/senior/agents"
  else
    return 1
  fi
}

detect_skills() {
  local base="$1"
  if [[ -d "$base/skills/skills" && -d "$base/skills/senior/skills" ]]; then
    SKILLS_SRC="$base/skills/skills"
    SENIOR_SKILLS_SRC="$base/skills/senior/skills"
    COMMANDS_SRC="$base/skills/commands"
  elif [[ -d "$base/skills/web" && -d "$base/senior/skills" ]]; then
    SKILLS_SRC="$base/skills"
    SENIOR_SKILLS_SRC="$base/senior/skills"
    COMMANDS_SRC="$base/commands"
  else
    return 1
  fi
}

download_repo() {
  local repo="$1" dest="$2"
  mkdir -p "$dest"
  local url="https://codeload.github.com/xscriptor-ai/$repo/tar.gz/refs/heads/$XSCRIPTOR_REF"
  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    echo "    downloading xscriptor-ai/$repo@$XSCRIPTOR_REF"
    curl -fsSL "$url" | tar -xz -C "$dest" --strip-components=1
  else
    rm -rf "$dest"
    git clone --depth 1 --branch "$XSCRIPTOR_REF" "https://github.com/xscriptor-ai/$repo.git" "$dest"
  fi
}

for base in "${XSCRIPTOR_AGENTS_DIR:-}" "${XSCRIPTOR_SKILLS_DIR:-}" "$PARENT_DIR"; do
  [[ -z "$base" ]] && continue
  if [[ -z "$AGENTS_SRC" ]]; then detect_agents "$base" || true; fi
  if [[ -z "$SKILLS_SRC" ]]; then detect_skills "$base" || true; fi
done

ensure_sources() {
  if [[ -n "$AGENTS_SRC" && -n "$SKILLS_SRC" ]]; then return; fi
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  if [[ -z "$AGENTS_SRC" ]]; then
    download_repo agents "$TMP_DIR/agents-repo"
    detect_agents "$TMP_DIR/agents-repo" || { echo "error: invalid agents repo" >&2; exit 1; }
  fi
  if [[ -z "$SKILLS_SRC" ]]; then
    download_repo skills "$TMP_DIR/skills-repo"
    detect_skills "$TMP_DIR/skills-repo" || { echo "error: invalid skills repo" >&2; exit 1; }
  fi
}

# --- Group definitions ---
ALL_GROUPS=(
  general languages web/security web/architecture web/frontend web/backend
  mobile data-ml cloud testing graphql embedded game-dev content observability compliance
  security/recon security/web-pentest security/mobile-pentest security/desktop security/red-team
  security/blue-team security/ai-ml-security security/purple-team
  automotive-security aviation-security blockchain-security github hardware-security
  mainframe-security maritime-security medical-security mega physical-security
  privacy-engineering systems telecom-security
)

SENIOR_GROUPS=(
  cloud compliance content data-ml game-dev github go java-kotlin
  mobile python rust security systems testing typescript web
)

SENIOR_SKILLS=(
  api-design architecture cloud deployment go java-kotlin mobile
  monorepo observability performance python rust secure-coding security
  systems testing typescript web
)

# --- Helpers ---
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install Xscriptor AI agents, skills, and commands for OpenCode."
  echo ""
  echo "Selection (default: --all):"
  echo "  --all              Everything: agents + senior + skills + commands"
  echo "  --agents           Specialized agents only"
  echo "  --senior           Senior agents only"
  echo "  --skills           Skills only (project + senior)"
  echo "  --commands         Commands only"
  echo "  --groups LIST      Comma-separated groups (e.g. general,web/frontend)"
  echo "  --interactive      Select groups interactively"
  echo ""
  echo "Destination (default: --global):"
  echo "  --global           Install to OpenCode global dir (~/.config/opencode/)"
  echo "  --project          Install to .opencode/ in current directory"
  echo ""
  echo "Other:"
  echo "  --dry-run          Preview without copying"
  echo "  --list             List available groups"
  echo "  --help             Show this help"
}

detect_opencode_agents() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  echo "$base/opencode/agents"
}

detect_opencode_skills() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  echo "$base/opencode/skills"
}

detect_project_agents() {
  echo "$(pwd)/.opencode/agents"
}

detect_project_skills() {
  echo "$(pwd)/.opencode/skills"
}

detect_project_commands() {
  echo "$(pwd)/.opencode/commands"
}

copy_file() {
  local src="$1" dst="$2"
  if [[ -n "${DRY_RUN:-}" ]]; then
    echo "    - $(basename "$src")"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "    + $(basename "$src")"
  fi
  INSTALL_COUNT=$((INSTALL_COUNT + 1))
}

# --- Resolve mode ---
MODE="all"
DEST_MODE="global"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all"; shift ;;
    --agents) MODE="agents"; shift ;;
    --senior) MODE="senior"; shift ;;
    --skills) MODE="skills"; shift ;;
    --commands) MODE="commands"; shift ;;
    --groups) MODE="groups"; IFS=',' read -ra GROUP_SELECT <<< "$2"; shift 2 ;;
    --interactive) MODE="interactive"; shift ;;
    --global) DEST_MODE="global"; shift ;;
    --project) DEST_MODE="project"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list)
      ensure_sources
      echo "Available agent groups:"
      for g in "${ALL_GROUPS[@]}"; do
        c=$(find "$AGENTS_SRC/$g" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        echo "  $g ($c agents)"
      done
      echo ""
      echo "Senior agent groups:"
      for g in "${SENIOR_GROUPS[@]}"; do
        c=$(find "$SENIOR_SRC/$g" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        echo "  $g ($c agents)"
      done
      echo ""
      echo "Senior skills: ${#SENIOR_SKILLS[@]}"
      exit 0
      ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

ensure_sources

# --- Resolve destination ---
if [[ "$DEST_MODE" == "project" ]]; then
  AGENTS_DST=$(detect_project_agents)
  SKILLS_DST=$(detect_project_skills)
  COMMANDS_DST=$(detect_project_commands)
else
  AGENTS_DST=$(detect_opencode_agents)
  SKILLS_DST=$(detect_opencode_skills)
  COMMANDS_DST=$(detect_opencode_agents | sed 's/agents/commands/')
fi

# --- Execute ---
echo "==> Xscriptor AI Installer"
echo "    Mode: $MODE"
echo "    Agents → $AGENTS_DST"
echo "    Skills → $SKILLS_DST"
echo "    Commands → $COMMANDS_DST"
echo ""

INSTALL_COUNT=0

# --- Install specialized agents ---
install_agents() {
  local src="$1" dst="$2" desc="$3"
  shift 3
  local groups=("$@")
  echo "  [$desc]"
  for group in "${groups[@]}"; do
    local gs="$src/$group"
    if [[ ! -d "$gs" ]]; then
      echo "    [SKIP] $group"
      continue
    fi
    local files=("$gs"/*.md)
    if [[ ! -f "${files[0]}" ]]; then
      echo "    [SKIP] $group (empty)"
      continue
    fi
    echo "    [$group]"
    for f in "${files[@]}"; do
      copy_file "$f" "$dst/$(basename "$f")"
    done
  done
}

# --- Install skills ---
install_skill() {
  local name="$1" src="$2" dst="$3"
  local skill_dir="$dst/$name"
  if [[ -f "$src/SKILL.md" ]]; then
    echo "    [${name}]"
    if [[ -n "${DRY_RUN:-}" ]]; then
      echo "      - SKILL.md"
    else
      mkdir -p "$skill_dir"
      cp "$src/SKILL.md" "$skill_dir/SKILL.md"
      echo "      + SKILL.md"
    fi
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
    local refs="$src/references"
    if [[ -d "$refs" ]]; then
      if [[ -n "${DRY_RUN:-}" ]]; then
        echo "      - references/"
      else
        cp -r "$refs"/* "$skill_dir/references/" 2>/dev/null || true
        echo "      + references/"
      fi
    fi
  fi
}

# --- Mode dispatch ---
RUN_STANDARD=1

ask_yes() {
  local ans
  read -r -p "$1 [Y/n] " ans || true
  [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

install_commands() {
  echo "  [Commands]"
  if [[ -d "$COMMANDS_SRC" ]]; then
    for cmd in "$COMMANDS_SRC"/*.md; do
      if [[ -f "$cmd" && "$(basename "$cmd")" != "README.md" ]]; then
        copy_file "$cmd" "$COMMANDS_DST/$(basename "$cmd")"
      fi
    done
  fi
}

install_all_skills() {
  echo "  [Skills]"
  install_skill "xscriptor" "$SKILLS_SRC/web/literature/xscriptor" "$SKILLS_DST"
  install_skill "devx" "$SKILLS_SRC/web/dev/devx/devx" "$SKILLS_DST"
  install_skill "samurai" "$SKILLS_SRC/web/cybersec/samurai" "$SKILLS_DST"
  for sk in "${SENIOR_SKILLS[@]}"; do
    install_skill "$sk" "$SENIOR_SKILLS_SRC/$sk" "$SKILLS_DST"
  done
}

if [[ "$MODE" == "interactive" ]]; then
  RUN_STANDARD=0
  echo "Select specialized agent groups:"
  idx=1
  for g in "${ALL_GROUPS[@]}"; do
    c=$(find "$AGENTS_SRC/$g" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    printf '  %2d) %-28s %s agents\n' "$idx" "$g" "$c"
    idx=$((idx + 1))
  done
  echo "  Enter numbers separated by commas (e.g. 1,3,5), or leave empty for all:"
  read -r -p "> " selection || true
  GROUP_SELECT=()
  if [[ -z "${selection:-}" ]]; then
    GROUP_SELECT=("${ALL_GROUPS[@]}")
  else
    IFS=',' read -ra nums <<< "$selection"
    for n in "${nums[@]}"; do
      n="${n// /}"
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#ALL_GROUPS[@]} )); then
        GROUP_SELECT+=("${ALL_GROUPS[$((n - 1))]}")
      else
        echo "  ignoring invalid selection: $n" >&2
      fi
    done
  fi
  if [[ ${#GROUP_SELECT[@]} -gt 0 ]]; then
    install_agents "$AGENTS_SRC" "$AGENTS_DST" "Specialized Agents" "${GROUP_SELECT[@]}"
  fi
  if ask_yes "Install senior agents?"; then
    install_agents "$SENIOR_SRC" "$AGENTS_DST" "Senior Agents" "${SENIOR_GROUPS[@]}"
  fi
  if ask_yes "Install commands?"; then
    install_commands
  fi
  if ask_yes "Install skills (project + senior)?"; then
    install_all_skills
  fi
fi

if [[ "$RUN_STANDARD" == 1 ]]; then
  if [[ "$MODE" == "all" || "$MODE" == "agents" || "$MODE" == "groups" ]]; then
    if [[ "$MODE" == "groups" ]]; then
      install_agents "$AGENTS_SRC" "$AGENTS_DST" "Agents" "${GROUP_SELECT[@]}"
    else
      install_agents "$AGENTS_SRC" "$AGENTS_DST" "Specialized Agents" "${ALL_GROUPS[@]}"
    fi
  fi

  if [[ "$MODE" == "all" || "$MODE" == "senior" ]]; then
    install_agents "$SENIOR_SRC" "$AGENTS_DST" "Senior Agents" "${SENIOR_GROUPS[@]}"
  fi

  if [[ "$MODE" == "all" || "$MODE" == "commands" ]]; then
    install_commands
  fi

  if [[ "$MODE" == "all" || "$MODE" == "skills" ]]; then
    install_all_skills
  fi
fi

# --- Report ---
echo ""
if [[ -n "${DRY_RUN:-}" ]]; then
  echo "==> Dry run: $INSTALL_COUNT items would be installed."
else
  echo "==> $INSTALL_COUNT items installed."
  echo ""
  echo "  Agents:   $AGENTS_DST"
  echo "  Skills:   $SKILLS_DST"
  echo ""
  echo "  Repo:     https://github.com/xscriptor-ai/scripts"
fi
