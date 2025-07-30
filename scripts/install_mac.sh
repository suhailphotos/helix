#!/usr/bin/env bash
set -euo pipefail

echo "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing packages with Homebrew…"
brew update

brew bundle --file=- <<'BREWFILE'
brew "git"
brew "neovim"
brew "stow"
brew "ripgrep"
brew "fd"
brew "lazygit"
brew "bottom"
brew "node"
brew "python"
brew "gdu"
cask "wezterm"        # optional terminal
BREWFILE

echo "Stowing dot-files…"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
stow nvim iterm tmux

echo "Installing Neovim plugins (first run)…"
nvim --headless -u NONE "+lua require('bootstrap')" >/dev/null
echo "All set!  Launch nvim normally."
