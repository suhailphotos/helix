#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
# Detach stdin so piped runs don’t get eaten by brew’s tee internals
exec </dev/null

# -----------------------------
# Flags (keep old behavior)
# -----------------------------
WITH_SF_FONTS=0
ONLY_SF_FONTS=0
RUN_ALL=0
RUN_POETRY=0
LIMIT_HOST="${LIMIT_HOST:-}"  # optional, overrides auto-detect
# ---- end flags --------------

print_usage() {
  cat <<'EOF'
Usage examples

Default (skip SF fonts):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"

Include SF fonts:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts

Only SF fonts:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts

All (base + fonts + poetry):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --all

Optional:
  --limit HOST   (override auto-detected host)
EOF
}

# Parse flags (supports both ... | bash -s -- ... and bash -c "..." -- ...)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf_fonts|--sf-fonts) WITH_SF_FONTS=1 ;;
    --only_sf_fonts|--fonts-only) WITH_SF_FONTS=1; ONLY_SF_FONTS=1 ;;
    --poetry) RUN_POETRY=1 ;;
    --all) RUN_ALL=1 ;;
    --limit) LIMIT_HOST="${2:-}"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown flag: $1"; echo; print_usage; exit 2 ;;
  esac
  shift
done

if [[ "$RUN_ALL" -eq 1 ]]; then
  WITH_SF_FONTS=1
  RUN_POETRY=1
fi

if [[ "$ONLY_SF_FONTS" -eq 1 && "$RUN_POETRY" -eq 1 ]]; then
  echo "Refusing: --only_sf_fonts cannot be combined with --poetry (poetry needs the base toolchain)."
  exit 2
fi

# -----------------------------
# Helpers
# -----------------------------
# Keep sudo alive while we run (for Homebrew, casks, etc.)
keep_sudo_alive() {
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      echo "Requesting admin privileges…"
      sudo -v
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  fi
}

# Add brew shellenv to ~/.zprofile (idempotent), and eval for this shell
ensure_brew_shellenv() {
  local brew_bin="$1"
  local zprof="$HOME/.zprofile"
  local line='eval "$('"$brew_bin"' shellenv)"'
  if ! grep -qxF "$line" "$zprof" 2>/dev/null; then
    {
      echo
      echo "$line"
    } >> "$zprof"
  fi
  eval "$("$brew_bin" shellenv)"
}

# Detect current host and see if it exists in inventory
auto_limit_host() {
  local inv="$1"
  [[ -n "$LIMIT_HOST" ]] && { echo "$LIMIT_HOST"; return 0; }
  # Try several names commonly used on macOS
  local cands=()
  cands+=("$(scutil --get ComputerName 2>/dev/null || true)")
  cands+=("$(scutil --get LocalHostName 2>/dev/null || true)")
  cands+=("$(hostname -s 2>/dev/null || true)")
  for raw in "${cands[@]}"; do
    h="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    [[ -z "$h" ]] && continue
    if grep -qiE "^[[:space:]]+${h}:[[:space:]]*$" "$inv"; then
      echo "$h"; return 0
    fi
  done
  # no match → return empty; playbook pre_task will prune anyway
  echo ""
}

# -----------------------------
# Repo + toolchain bootstraps
# -----------------------------
HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
CACHE_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_checkout}"

# Xcode CLT
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Run: xcode-select --install"
  exit 1
fi

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  keep_sudo_alive
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

BREW_BIN=""
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN=/usr/local/bin/brew
else
  echo "Homebrew install finished but brew not found on standard paths." >&2
  exit 1
fi
ensure_brew_shellenv "$BREW_BIN"

# Ansible
if ! command -v ansible-playbook >/dev/null 2>&1; then
  "$BREW_BIN" install ansible
fi

# Repo cache/update
if [[ ! -d "$CACHE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --depth 1 --branch "$HELIX_BRANCH" "$HELIX_REPO_URL" "$CACHE_DIR"
else
  git -C "$CACHE_DIR" fetch --prune origin
  git -C "$CACHE_DIR" reset --hard "origin/$HELIX_BRANCH"
fi

ANS_DIR="$CACHE_DIR/ansible"
INV_FILE="$ANS_DIR/inventory.yml"

# Ensure collections
cd "$ANS_DIR"
export ANSIBLE_CONFIG="$ANS_DIR/ansible.cfg"
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

# Auto-limit (local convenience; safe to omit)
AUTO_LIMIT="$(auto_limit_host "$INV_FILE")"

# Build play args
PLAY="playbooks/macos_local.yml"
args=( -i "$INV_FILE" "$PLAY" -K )
[[ -n "$AUTO_LIMIT" ]] && args+=( --limit "$AUTO_LIMIT" )
[[ "$WITH_SF_FONTS" -eq 1 ]] && args+=( -e enable_sf_fonts=true )
[[ "$ONLY_SF_FONTS" -eq 1 ]] && args+=( --tags fonts )

echo "==> Running macOS bootstrap ${ONLY_SF_FONTS:+(fonts only)} ${AUTO_LIMIT:+(limit=$AUTO_LIMIT)}"
ansible-playbook "${args[@]}"

# Optional: run Poetry envs (same limit if resolved)
if [[ "$RUN_POETRY" -eq 1 ]]; then
  echo "==> Running Poetry envs ${AUTO_LIMIT:+(limit=$AUTO_LIMIT)}"
  ansible-playbook -i "$INV_FILE" playbooks/poetry_envs.yml -K ${AUTO_LIMIT:+--limit "$AUTO_LIMIT"}
fi

echo "🎉 Done."
