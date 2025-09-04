#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

REPO_URL="https://github.com/suhailphotos/helix.git"
CACHE_DIR="${HOME}/.cache/helix_checkout"
ANS_DIR="${CACHE_DIR}/ansible"
INV_FILE="${ANS_DIR}/inventory.yml"
PLAY="${ANS_DIR}/playbooks/desktop_apps.yml"

# Xcode CLT
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Run: xcode-select --install" >&2
  exit 1
fi

# Homebrew + Ansible
if ! command -v brew >/dev/null 2>&1; then
  # sudo keepalive
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      echo "Requesting admin privileges to install Homebrew…"
      sudo -v
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  fi
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
if ! command -v ansible-playbook >/dev/null 2>&1; then
  brew install ansible >/dev/null
fi

# Repo cache
if [[ ! -d "$CACHE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --depth=1 --branch main "$REPO_URL" "$CACHE_DIR"
else
  git -C "$CACHE_DIR" fetch --prune origin
  git -C "$CACHE_DIR" reset --hard origin/main
fi

# Ensure required collections
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

# Run (pre_tasks auto-prune to this Mac)
ansible-playbook -i "$INV_FILE" "$PLAY" -K
