#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Flags
# -----------------------------
ENABLE_SF_FONTS=0
RUN_ALL=0
ONLY_SF_FONTS=0

print_usage() {
  cat <<'EOF'
Usage:
  Default (skip SF fonts):
    curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash

  With SF fonts:
    curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh | bash -s -- --sf_fonts

  Or with your original form:
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts

Flags:
  --sf_fonts       Include Apple SF fonts role
  --only_sf_fonts  Run only SF fonts (implies --sf_fonts)
  --all            Run everything (implies --sf_fonts)
  -h, --help       Show this help
EOF
}

# Parse flags robustly
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf_fonts|--sf-fonts) ENABLE_SF_FONTS=1 ;;
    --only_sf_fonts|--fonts-only) ENABLE_SF_FONTS=1; ONLY_SF_FONTS=1 ;;
    --all) RUN_ALL=1 ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;   # stop parsing at '--'
    *) echo "Unknown flag: $1"; echo; print_usage; exit 2 ;;
  esac
  shift
done

if [[ "$RUN_ALL" -eq 1 ]]; then
  ENABLE_SF_FONTS=1
fi

# Ask for sudo upfront (brew installer sometimes needs it) and keep alive.
if command -v sudo >/dev/null 2>&1; then
  sudo -v || true
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
fi

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_bootstrap}"

# Detect whether we're already in a helix checkout (dev runs)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || true)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || true)"
if [[ -n "${PARENT_DIR:-}" && -d "$PARENT_DIR/ansible" && -f "$PARENT_DIR/scripts/install_ansible_local.sh" ]]; then
  REPO_ROOT="$PARENT_DIR"
else
  # No local helix — clone/update to cache
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
  echo "Xcode Command Line Tools not found."
  echo "Please run: xcode-select --install"
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
  hash -r 2>/dev/null || true
  rehash 2>/dev/null || true
fi

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

cd "$REPO_ROOT/ansible"
ansible-playbook -i inventory.yml playbooks/macos_local.yml -K \
  "${EXTRA_VARS[@]}" "${PLAY_OPTS[@]}"

echo
echo "🎉 Done."
echo "Open iTerm2 and import: ~/Downloads/suhail_item2_profiles.json + ~/Downloads/suhailTerm2.itermcolors"
