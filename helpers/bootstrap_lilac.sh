#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
GH_USER="suhailphotos"                # your GitHub username
REPO="lilac"                           # repository name
DESCRIPTION="Lilac – a cozy purple-leaning theme family for Neovim, tmux, Ghostty, and iTerm (Catppuccin-powered)."
PRIVACY="public"                       # public | private | internal
: "${MATRIX:?Set MATRIX to your matrix root, e.g. /Users/suhail/Dropbox/matrix}"
DEST_DIR="$MATRIX/$REPO"

# --- CHECKS ---
command -v gh >/dev/null 2>&1 || { echo "❌ GitHub CLI (gh) not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ git not found"; exit 1; }

# verify gh auth
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "❌ gh is not authenticated for github.com"
  exit 1
fi

# --- CREATE REPO ON GITHUB (if missing) ---
if gh repo view "$GH_USER/$REPO" >/dev/null 2>&1; then
  echo "ℹ️  Repo $GH_USER/$REPO already exists on GitHub. Skipping creation."
else
  echo "🚀 Creating GitHub repo: $GH_USER/$REPO ($PRIVACY)"
  gh repo create "$GH_USER/$REPO" --$PRIVACY --description "$DESCRIPTION" --disable-wiki --confirm
fi

# --- CLONE LOCALLY ---
if [ -e "$DEST_DIR" ] && [ "$(ls -A "$DEST_DIR" 2>/dev/null || true)" != "" ]; then
  echo "❌ Destination exists and is not empty: $DEST_DIR"
  exit 1
fi
mkdir -p "$DEST_DIR"
if [ ! -d "$DEST_DIR/.git" ]; then
  echo "📥 Cloning into $DEST_DIR"
  git clone "https://github.com/$GH_USER/$REPO.git" "$DEST_DIR"
fi
cd "$DEST_DIR"

echo "🔧 Setting repo description (idempotent)"
gh repo edit "$GH_USER/$REPO" --description "$DESCRIPTION"

# --- WRITE README & LICENSE CONTENT (first commit) ---
YEAR="$(date +%Y)"
AUTHOR="Suhail"

cat > README.md <<'EOF'
# Lilac

A cozy purple-leaning theme family for **Neovim**, **tmux**, **Ghostty**, and **iTerm** — Catppuccin-powered.

## Flavors
- `lilac-nightbloom` — dark / high-contrast
- `lilac-mistbloom` — soft / slate
- (future) `lilac-emberbloom` — warm dark
- (future) `lilac-pearlbloom` — light

## Layout (generated + hand-authored)
```
/ (repo root)
├─ palettes/          # YAML source of truth (lilac-*.yml)
├─ tools/             # generators (e.g., gen.py)
├─ colors/            # Neovim colorschemes (generated)
├─ lua/lilac/         # Neovim theme module (generated + hand)
├─ plugin/            # Neovim commands (hand)
├─ tmux/              # tmux theme file(s) (generated)
├─ ghostty/themes/    # Ghostty pallets (generated)
└─ iterm/             # .itermcolors (generated)
```

## Quick start (later)
- Edit palettes in `palettes/`
- Run generator to produce Nvim/tmux/Ghostty/iTerm files
- Load the Nvim theme via lazy.nvim and `:colorscheme lilac-nightbloom`
EOF

cat > LICENSE <<EOF
MIT License

Copyright (c) $YEAR $AUTHOR

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# --- FOLDERS & EMPTY FILES ---
mkdir -p palettes tools lua/lilac colors plugin ghostty/themes tmux iterm scripts

# empty placeholders you will fill later
: > tools/gen.py
: > plugin/lilac.lua
: > lua/lilac/init.lua
: > tmux/lilac.tmux
: > palettes/lilac-nightbloom.yml
: > palettes/lilac-mistbloom.yml
: > ghostty/themes/lilac-nightbloom
: > ghostty/themes/lilac-mistbloom
: > iterm/lilac-nightbloom.itermcolors
: > iterm/lilac-mistbloom.itermcolors
: > colors/.gitkeep
: > scripts/.gitkeep

# --- INITIAL COMMIT ---
git add .
if git diff --cached --quiet; then
  echo "ℹ️  Nothing to commit."
else
  git commit -m "chore: bootstrap Lilac repo (README, LICENSE, structure)"
  git push -u origin HEAD
fi

echo "✅ Done."
echo "Repo: https://github.com/$GH_USER/$REPO"
echo "Local: $DEST_DIR"

