#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR

# Detach stdin so subcommands that read stdin (e.g., sudo/tee during brew install)
# don't slurp the rest of this script when using `curl ... | bash`.
exec </dev/null

# -----------------------------
# Flags
# -----------------------------
ENABLE_SF_FONTS=0
RUN_ALL=0
ONLY_SF_FONTS=0

print_usage() {
  cat <<'EOF'
Usage examples

Default (skip SF fonts):
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash
  # or
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"

Include SF fonts:
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash -s -- --sf_fonts
  # or
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts

Only SF fonts:
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash -s -- --only_sf_fonts
  # or
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts

All (future catch-all):
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash -s -- --all
  # or
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --all

Flags:
  --sf_fonts       Include Apple SF fonts role
  --only_sf_fonts  Run only the fonts role (implies --sf_fonts)
  --all            Run everything (currently implies --sf_fonts)
  -h, --help       Show this help
EOF
}

# Parse flags (supports both ...| bash -s -- ... and bash -c "..." -- ...)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf_fonts|--sf-fonts) ENABLE_SF_FONTS=1 ;;
    --only_sf_fonts|--fonts-only) ENABLE_SF_FONTS=1; ONLY_SF_FONTS=1 ;;
    --all) RUN_ALL=1 ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;   # stop parsing flags
    *) echo "Unknown flag: $1"; echo; print_usage; exit 2 ;;
  esac
  shift
done

if [[ "$RUN_ALL" -eq 1 ]]; then
  ENABLE_SF_FONTS=1
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
SCRIPT_PATH="${BASH_SOURCE[0]:-}"  # may be empty when read from stdin or bash -c
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
ansible-galaxy collection install -r "$REPO_ROOT/ansible/collections/requirements.yml"

EXTRA_VARS=()
PLAY_OPTS=()

if [[ "$ENABLE_SF_FONTS" -eq 1 ]]; then
  EXTRA_VARS+=( -e enable_sf_fonts=true )
fi
if [[ "$ONLY_SF_FONTS" -eq 1 ]]; then
  PLAY_OPTS+=( --tags fonts )
fi

echo "==> Running Ansible playbook (local)"
cd "$REPO_ROOT/ansible"
ansible-playbook -i inventory.yml playbooks/macos_local.yml -K \
  "${EXTRA_VARS[@]}" "${PLAY_OPTS[@]}"

echo
echo "🎉 Done."
echo "Open iTerm2 and import: ~/Downloads/suhail_item2_profiles.json + ~/Downloads/suhailTerm2.itermcolors"
