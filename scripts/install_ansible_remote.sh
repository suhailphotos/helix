#!/usr/bin/env bash
set -euo pipefail

# Ask for sudo upfront on Linux paths
if command -v sudo >/dev/null 2>&1; then
  sudo -v || true
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
fi

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/helix-ansible}"

# Clone/update helix to a working dir (controller side)
if ! command -v git >/dev/null 2>&1; then
  echo "git is required on the controller."
  exit 1
fi
mkdir -p "$(dirname "$HELIX_LOCAL_DIR")"
if [[ -d "$HELIX_LOCAL_DIR/.git" ]]; then
  echo "==> Updating helix in $HELIX_LOCAL_DIR"
  git -C "$HELIX_LOCAL_DIR" fetch --quiet
  git -C "$HELIX_LOCAL_DIR" checkout "$HELIX_BRANCH" --quiet
  git -C "$HELIX_LOCAL_DIR" pull --ff-only --quiet
else
  echo "==> Cloning helix into $HELIX_LOCAL_DIR"
  git clone --depth 1 --branch "$HELIX_BRANCH" --quiet "$HELIX_REPO_URL" "$HELIX_LOCAL_DIR"
fi

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
    if ! command -v ansible-playbook >/dev/null 2>&1; then
      brew install ansible
      hash -r 2>/dev/null || true
      rehash 2>/dev/null || true
    fi
    ;;
  ubuntu|debian)
    sudo apt-get update -y
    sudo apt-get install -y ansible
    ;;
  *)
    echo "Please install Ansible manually for $OS."
    ;;
esac

echo "==> Ready. cd into: $HELIX_LOCAL_DIR"
echo "    ansible-playbook -i ansible/inventory.yml ansible/playbooks/macos_remote.yml --limit eclipse -K"
echo "    # Linux baseline (tree):"
echo "    ansible-playbook -i ansible/inventory.yml ansible/playbooks/linux_remote.yml --limit nimbus -K"
