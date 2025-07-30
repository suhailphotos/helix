#!/usr/bin/env bash
# One-shot bootstrap for macOS
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# 0.  Paths
DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTS_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# 1.  Homebrew + packages
if ! command -v brew >/dev/null 2>&1; then
  echo "🔧  Installing Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "🔧  Installing core packages ..."
brew bundle --file=- <<'BREW'
tap "homebrew/bundle"
brew "git"
brew "neovim"
brew "stow"
brew "ripgrep"
brew "fd"
brew "lazygit"
brew "bottom"
brew "node"
brew "python"      # python3 + pip
brew "gdu"         # optional: disk-usage tool for :<Leader>du
BREW

# ──────────────────────────────────────────────────────────────────────────────
# 2.  Neovim remote providers
python3 -m pip install --user --upgrade pynvim
npm install -g neovim

# ──────────────────────────────────────────────────────────────────────────────
# 3.  Dotfiles → $HOME
mkdir -p "$HOME/.config"

ln -sfn "$DOTS_DIR/nvim"  "$HOME/.config/nvim"   # Neovim (single link)
stow -vt "$HOME" tmux                           # other packages
stow -vt "$HOME" iterm || true                  # ignore if you don’t use iterm

# ──────────────────────────────────────────────────────────────────────────────
# 4.  Pull & lock all Neovim plugins
echo "🔧  Syncing Neovim plugins (Lazy) ..."
nvim --headless "+Lazy! sync" +qa

echo "✅  Helix (AstroNvim) ready.  Launch with: nvim"
