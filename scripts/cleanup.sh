#!/usr/bin/env bash

# Remove Treesitter build and temp dirs from Dropbox config (replace with your path if different)
rm -rf ~/Library/CloudStorage/Dropbox/matrix/helix/nvim/parsers
rm -rf ~/Library/CloudStorage/Dropbox/matrix/helix/nvim/ts_tmp
rm -rf ~/Library/CloudStorage/Dropbox/matrix/helix/nvim/tree-sitter-* 2>/dev/null || true
rm -rf ~/Library/CloudStorage/Dropbox/matrix/helix/nvim/tree-sitter-*-tmp 2>/dev/null || true

# Remove Treesitter build and temp dirs from LOCAL Neovim data/cache
rm -rf ~/.local/share/nvim/parsers
rm -rf ~/.local/share/nvim/ts_tmp
rm -rf ~/.local/share/nvim/tree-sitter-* 2>/dev/null || true
rm -rf ~/.local/share/nvim/tree-sitter-*-tmp 2>/dev/null || true

# (Optional) Clean Neovim cache
rm -rf ~/.cache/nvim

echo "Cleanup complete! All temp and parser dirs removed."
