#!/usr/bin/env bash
set -euo pipefail
echo "⬆️  Updating system packages…"
if command -v brew &>/dev/null; then
  brew update && brew upgrade
else
  sudo apt update && sudo apt upgrade -y
fi

echo "⬆️  Updating Neovim plugins…"
nvim --headless '+PackerSync' +qa

echo "✅  All up to date!"
