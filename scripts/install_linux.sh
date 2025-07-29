#!/usr/bin/env bash
set -euo pipefail

# 1) deps
brew install neovim tmux ripgrep fd stow

# 2) location
ROOT="/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix"
cd "$ROOT"

# 3) symlinks
mkdir -p "$HOME/.config"
stow -v -t "$HOME/.config" nvim
stow -v -t "$HOME" tmux

# 4) plugin sync
nvim --headless "+Lazy! sync" +qa

echo "Helix install complete."
