#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Library/CloudStorage/Dropbox/matrix/helix"  # adjust path on Linux
cd "$ROOT"

echo "▶ Installing base packages"
sudo apt update
sudo apt install -y \
  neovim git stow tmux ripgrep fd-find build-essential \
  python3 python3-pip nodejs npm

# optional extras used by Astro key-bindings
sudo apt install -y cargo && cargo install bottom lazygit

echo "▶ Symlinking configs"
mkdir -p "$HOME/.config"
stow -v nvim
stow -v tmux

echo "▶ Bootstrapping plugins"
nvim --headless "+Lazy! sync" +qa

echo ""
echo "✅ Neovim ready. Run: nvim"
