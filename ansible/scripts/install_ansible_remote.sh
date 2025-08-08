#!/usr/bin/env bash
set -euo pipefail

# Find repo root from script location
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  OS="$ID"
fi

echo "==> Ensuring Ansible is installed on controller ($OS)"
case "$OS" in
  macos)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew not found. Installing Homebrew (non-interactive)..."
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)" || true
      eval "$(/usr/local/bin/brew shellenv)" || true
    fi
    if ! command -v ansible >/dev/null 2>&1; then
      brew install ansible
    fi
    ;;
  ubuntu|debian)
    sudo apt-get update -y
    sudo apt-get install -y ansible
    ;;
  *)
    echo "Please install Ansible manually for your OS."
    ;;
esac

echo "==> Run a remote play when you're ready, e.g.:"
echo "    ansible-playbook -i inventory.yml playbooks/macos_remote.yml --limit eclipse -K"
