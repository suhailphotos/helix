#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

# Flags
LIMIT_HOST="eclipse"   # override with --limit quasar (etc.)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT_HOST="${2:-}"; shift ;;
    -h|--help)
      cat <<'EOF'
Usage:
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/run_poetry_envs.sh | bash -- --limit quasar
Flags:
  --limit HOST   Ansible --limit target (must exist in inventory.yml). Default: eclipse
EOF
      exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
  shift
done

# Ensure sudo keeps alive for -K runs (no-op if no sudo)
if command -v sudo >/dev/null 2>&1; then
  sudo -v || true
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
fi

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_bootstrap}"

# Use repo next to this script if present; else clone/update to cache
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  PARENT_DIR=""
fi
if [[ -n "$PARENT_DIR" && -d "$PARENT_DIR/ansible" ]]; then
  REPO_ROOT="$PARENT_DIR"
else
  command -v git >/dev/null 2>&1 || { echo "git required"; exit 1; }
  mkdir -p "$(dirname "$HELIX_LOCAL_DIR")"
  if [[ -d "$HELIX_LOCAL_DIR/.git" ]]; then
    git -C "$HELIX_LOCAL_DIR" fetch --quiet
    git -C "$HELIX_LOCAL_DIR" checkout "$HELIX_BRANCH" --quiet
    git -C "$HELIX_LOCAL_DIR" pull --ff-only --quiet
  else
    git clone --depth 1 --branch "$HELIX_BRANCH" --quiet "$HELIX_REPO_URL" "$HELIX_LOCAL_DIR"
  fi
  REPO_ROOT="$HELIX_LOCAL_DIR"
fi

# Make sure Ansible exists (same pattern as your other installer)
if [[ "$OSTYPE" == "darwin"* ]]; then
  BREW_BIN=""
  if [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW_BIN=/opt/homebrew/bin/brew
  fi
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    "$BREW_BIN" install ansible
    eval "$("$BREW_BIN" shellenv)"
  fi
else
  command -v ansible-playbook >/dev/null 2>&1 || { echo "Install Ansible first."; exit 1; }
fi

echo "==> Installing required Ansible collections"
ansible-galaxy collection install -r "$REPO_ROOT/ansible/collections/requirements.yml" || true

cd "$REPO_ROOT/ansible"
echo "==> Running Poetry envs for --limit ${LIMIT_HOST}"
ansible-playbook -i inventory.yml playbooks/poetry_envs.yml --limit "${LIMIT_HOST}" -K
