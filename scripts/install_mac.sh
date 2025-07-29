#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix"
cd "$ROOT"

echo "▶ Installing base tools with Homebrew"
brew update
brew install neovim git stow tmux ripgrep fd lazygit bottom python node go

echo "▶ Symlinking configs with stow"
mkdir -p "$HOME/.config"
stow -v nvim   # → ~/.config/nvim  (thanks to .stowrc target)
stow -v tmux   # → ~/.tmux.conf

echo "▶ Pulling plugins (Lazy + AstroNvim)"
nvim --headless "+Lazy! sync" +qa

echo ""
echo "All set! Launch Neovim with: nvim"
