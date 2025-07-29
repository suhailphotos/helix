#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix"
cd "$ROOT"

echo "▶ Pulling latest Helix repo"
git pull --ff-only

echo "▶ Updating plugins & AstroNvim"
nvim --headless "+Lazy! sync" +qa

echo "Helix and plugins are up to date"
