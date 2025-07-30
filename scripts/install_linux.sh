#!/usr/bin/env bash
# One-shot bootstrap for Linux
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTS_DIR"

install_pkgs_apt() {
  sudo apt update
  sudo apt install -y git neovim stow ripgrep fd-find \
    lazygit bottom nodejs npm python3 python3-pip gdu
  # fd binary name adjustment
  if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi
}

install_pkgs_pacman() {
  sudo pacman -Syu --needed --noconfirm git neovim stow ripgrep fd \
    lazygit bottom nodejs npm python python-pip gdu
}

echo "🔧  Installing core packages ..."
if   command -v apt   >/dev/null 2>&1; then install_pkgs_apt
elif command -v pacman>/dev/null 2>&1; then install_pkgs_pacman
else
  echo "⚠️  Unsupported distro – please install the required packages manually."
  exit 1
fi

# Providers
python3 -m pip install --user --upgrade pynvim
npm install -g neovim

# Dotfiles
mkdir -p "$HOME/.config"
ln -sfn "$DOTS_DIR/nvim" "$HOME/.config/nvim"
stow -vt "$HOME" tmux

# Plugins
echo "🔧  Syncing Neovim plugins (Lazy) ..."
nvim --headless "+Lazy! sync" +qa

echo "✅  Helix (AstroNvim) ready.  Launch with: nvim"
