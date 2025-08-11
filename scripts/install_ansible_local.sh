#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR

# Detach stdin so subcommands (e.g. brew's internal tee) don't eat the rest of this script when using `curl ... | bash`.
exec </dev/null

# -----------------------------
# Flags
# -----------------------------
ENABLE_SF_FONTS=0
RUN_ALL=0
ONLY_SF_FONTS=0
RUN_POETRY=0
# --- Default Host
DEFAULT_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
if [[ -z "${LIMIT_HOST:-}" ]]; then
  LIMIT_HOST="$DEFAULT_HOST"
fi
echo "==> Target host: ${LIMIT_HOST}"
# ---- end flags --------------

print_usage() {
  cat <<'EOF'
Usage examples

Default (skip SF fonts):
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash
  # or
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"

Include SF fonts:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts

Only SF fonts:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts

All (base + fonts + poetry):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --all --limit quasar

Poetry only (after a base run):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --poetry --limit quasar

Flags:
  --sf_fonts         Include Apple SF fonts role
  --only_sf_fonts    Run only the fonts role (implies --sf_fonts)
  --poetry           Run the Poetry envs playbook (after base playbook)
  --limit HOST       Limit Poetry envs run to a host in inventory (default: eclipse)
  --all              Run everything (base + fonts + poetry)
  -h, --help         Show this help
EOF
}

# Parse flags (supports both ...| bash -s -- ... and bash -c "..." -- ...)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf_fonts|--sf-fonts) ENABLE_SF_FONTS=1 ;;
    --only_sf_fonts|--fonts-only) ENABLE_SF_FONTS=1; ONLY_SF_FONTS=1 ;;
    --all) RUN_ALL=1 ;;
    --poetry) RUN_POETRY=1 ;;
    --limit) LIMIT_HOST="${2:-}"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown flag: $1"; echo; print_usage; exit 2 ;;
  esac
  shift
done

if [[ "$RUN_ALL" -eq 1 ]]; then
  ENABLE_SF_FONTS=1
  RUN_POETRY=1
fi

# Disallow: --only_sf_fonts together with --poetry (poetry needs base toolchain)
if [[ "$ONLY_SF_FONTS" -eq 1 && "$RUN_POETRY" -eq 1 ]]; then
  echo "Refusing to run: --only_sf_fonts cannot be combined with --poetry (poetry needs the base toolchain)."
  echo "Run without --only_sf_fonts, or run --poetry after a normal base run."
  exit 2
fi

# Ask for sudo upfront (keep alive)
if command -v sudo >/dev/null 2>&1; then
  sudo -v || true
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
fi

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_bootstrap}"

# Detect whether we're running from a file or via stdin (curl | bash)
SCRIPT_PATH="${BASH_SOURCE[0]:-}"  # empty when read from stdin or bash -c
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  PARENT_DIR=""
fi

# Use repo next to this script if present; otherwise clone to cache
if [[ -n "$PARENT_DIR" && -d "$PARENT_DIR/ansible" && -f "$PARENT_DIR/scripts/install_ansible_local.sh" ]]; then
  REPO_ROOT="$PARENT_DIR"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Please install Xcode CLT first: xcode-select --install"
    exit 1
  fi
  mkdir -p "$(dirname "$HELIX_LOCAL_DIR")"
  if [[ -d "$HELIX_LOCAL_DIR/.git" ]]; then
    echo "==> Updating helix in $HELIX_LOCAL_DIR (branch: $HELIX_BRANCH)"
    git -C "$HELIX_LOCAL_DIR" fetch --quiet
    git -C "$HELIX_LOCAL_DIR" checkout "$HELIX_BRANCH" --quiet
    git -C "$HELIX_LOCAL_DIR" pull --ff-only --quiet
  else
    echo "==> Cloning helix into $HELIX_LOCAL_DIR"
    git clone --depth 1 --branch "$HELIX_BRANCH" --quiet "$HELIX_REPO_URL" "$HELIX_LOCAL_DIR"
  fi
  REPO_ROOT="$HELIX_LOCAL_DIR"
fi

echo "==> Checking Xcode Command Line Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Run: xcode-select --install"
  exit 1
fi

echo "==> Checking Homebrew..."
BREW_BIN=""
if [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
else
  echo "Homebrew not found. Installing Homebrew (non-interactive)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN=/usr/local/bin/brew
  else
    echo "Failed to install Homebrew. Aborting."
    exit 1
  fi
fi

echo "==> Ensuring brew shellenv in ~/.zprofile and current shell"
ZPROFILE="$HOME/.zprofile"
LINE='eval "$('"$BREW_BIN"' shellenv)"'
grep -qxF "$LINE" "$ZPROFILE" 2>/dev/null || echo "$LINE" >> "$ZPROFILE"
eval "$("$BREW_BIN" shellenv)"

echo "==> Installing Ansible via Homebrew (if missing)"
if ! command -v ansible-playbook >/dev/null 2>&1; then
  "$BREW_BIN" install ansible

  # Refresh command cache *safely* (bash has `hash -r`, zsh has `rehash`)
  if hash hash 2>/dev/null; then hash -r || true; fi
  if command -v rehash >/dev/null 2>&1; then rehash || true; fi

  # Make sure PATH from Homebrew is live in this process
  eval "$("$BREW_BIN" shellenv)"
fi

# Sanity check
echo "==> Ansible detected: $(ansible-playbook --version | head -1)"

echo "==> Installing required Ansible collections"
ansible-galaxy collection install -r "$REPO_ROOT/ansible/collections/requirements.yml" || true

# Build arg list safely (works with set -u)
cd "$REPO_ROOT/ansible"
PLAYBOOK_ARGS=( -i inventory.yml playbooks/macos_local.yml --limit "${LIMIT_HOST}" -K )
if [[ "$ENABLE_SF_FONTS" -eq 1 ]]; then
  PLAYBOOK_ARGS+=( -e enable_sf_fonts=true )
fi
if [[ "$ONLY_SF_FONTS" -eq 1 ]]; then
  PLAYBOOK_ARGS+=( --tags fonts )
fi

echo "==> Running Ansible playbook (local) ${ONLY_SF_FONTS:+[fonts only]} (limit=${LIMIT_HOST})"
ansible-playbook "${PLAYBOOK_ARGS[@]}"

# Optionally run Poetry envs (after base has installed pyenv/poetry)
if [[ "$RUN_POETRY" -eq 1 ]]; then
  echo "==> Running Poetry envs (limit=${LIMIT_HOST})"
  ansible-playbook -i inventory.yml playbooks/poetry_envs.yml --limit "${LIMIT_HOST}" -K
fi

echo
echo "🎉 Done."
echo "Open iTerm2 and import: ~/Downloads/suhail_item2_profiles.json + ~/Downloads/suhailTerm2.itermcolors"


