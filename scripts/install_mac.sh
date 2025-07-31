#!/usr/bin/env bash
#
#  scripts/install_mac.sh
#  ----------------------
#  One-shot bootstrap for a fresh macOS machine.
#
#  • Installs Homebrew + packages
#  • Clones (or updates) the helix repo
#  • Stows dot-files into $HOME
#  • Headless Neovim plugin + Tree-sitter install
#  -------------------------------------------------------------

set -euo pipefail

# ────────────────────────────────────────────────────────────────
# 0. Where should the repo live?
#    Keep the default when already cloned, otherwise ask once.
# ────────────────────────────────────────────────────────────────
DEFAULT_DIR="$HOME/Library/CloudStorage/Dropbox/matrix/helix"
if [[ -d "$DEFAULT_DIR/.git" ]]; then
  HELIX_DIR="$DEFAULT_DIR"
else
  read -rp "Clone helix to which directory? [$DEFAULT_DIR] " HELIX_DIR
  HELIX_DIR=${HELIX_DIR:-$DEFAULT_DIR}
  echo "→ cloning into $HELIX_DIR"
  git clone https://github.com/<YOUR-GH-USER>/helix.git "$HELIX_DIR"
fi
cd "$HELIX_DIR"

# ────────────────────────────────────────────────────────────────
# 1. Homebrew + formulae
# ────────────────────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  echo "→ installing Homebrew …"
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

BREW_PKGS=(
  git neovim stow ripgrep fd lazygit bottom node python gdu wezterm
)
echo "→ installing brew packages …"
brew install "${BREW_PKGS[@]}"

# ────────────────────────────────────────────────────────────────
# 2. Stow dot-files
# ────────────────────────────────────────────────────────────────
echo "→ stowing dot-files …"
stow -R nvim iterm tmux

# ────────────────────────────────────────────────────────────────
# 3. Headless plugin sync  (lazy.nvim)
# ────────────────────────────────────────────────────────────────
echo "→ syncing Neovim plugins …"
nvim --headless "+Lazy! sync" +qa

# ────────────────────────────────────────────────────────────────
# 4. Tree-sitter – compile fixed language set once
#    (parser dir set in lua/plugins/init.lua)
# ────────────────────────────────────────────────────────────────
PARSER_DIR="$HOME/.local/share/nvim/parsers"
mkdir -p "$PARSER_DIR"

echo "→ installing Tree-sitter parsers …"
nvim --headless "+TSInstallSync vimdoc lua python javascript typescript rust c" +qa

# ────────────────────────────────────────────────────────────────
echo -e "\n✅  All done!  Launch Neovim normally and enjoy."
