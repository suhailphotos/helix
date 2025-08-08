#!/usr/bin/env bash
set -euo pipefail

# Find repo root from script location
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

echo "==> Ensuring brew shellenv in ~/.zprofile"
ZPROFILE="$HOME/.zprofile"
LINE='eval "$('"$BREW_BIN"' shellenv)"'
grep -qxF "$LINE" "$ZPROFILE" 2>/dev/null || echo "$LINE" >> "$ZPROFILE"

echo "==> Installing Ansible via Homebrew (if missing)"
if ! command -v ansible >/dev/null 2>&1; then
  "$BREW_BIN" install ansible
fi

echo "==> Running Ansible playbook (local)"
cd "$REPO_ROOT"
ansible-playbook -i inventory.yml playbooks/macos_local.yml -K

echo "==> Done. Open iTerm2 and import profile/colors from ~/Downloads as prompted."
