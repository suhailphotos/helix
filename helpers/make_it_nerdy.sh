#!/usr/bin/env bash
set -euo pipefail

# Prereqs (safe to re-run)
brew list --versions fontforge >/dev/null 2>&1 || brew install fontforge
brew list --versions git >/dev/null 2>&1 || brew install git

REPO="$HOME/src/nerd-fonts"
OUT="$HOME/fonts-out/SFMonoNerdFontMono"
TMP="$HOME/fonts-out/tmp_sfmono_fix"

mkdir -p "$(dirname "$REPO")" "$OUT" "$TMP"

# Get the patcher if missing
if [ ! -d "$REPO/.git" ]; then
  git clone --depth=1 https://github.com/ryanoasis/nerd-fonts "$REPO"
fi

echo "Finding SF-Mono faces…"
# POSIX-safe loop (no mapfile / no process substitution)
find /Library/Fonts "$HOME/Library/Fonts" /System/Library/Fonts \
  -maxdepth 1 -type f -iname 'SF-Mono-*.otf' -print0 |
while IFS= read -r -d '' SRC; do
  BASE="$(basename "$SRC" .otf)"
  FIXED="$TMP/${BASE}.ttf"
  echo "  Fixing flags and converting: $BASE -> $(basename "$FIXED")"
  fontforge -lang=ff -c 'Open($1); SetOS2Value("FSType", 0); Generate($2)' "$SRC" "$FIXED"

  echo "  Patching (mono + glyphs): $(basename "$FIXED")"
  fontforge -script "$REPO/font-patcher" --complete --mono --careful \
    "$FIXED" --outputdir "$OUT"
done

# Keep only faces terminals actually use (plus Medium/Semibold if you like)
echo "Pruning uncommon faces…"
cd "$OUT"
# Keep: Regular, Bold, Italic, BoldItalic, Medium, Semibold (and their italics)
ls | grep -Ev 'Regular|Bold|Italic|Medium|Semibold' | xargs -I{} rm -f "{}" || true
cd - >/dev/null

# Zip for AirDrop (avoids iCloud partial sync)
cd "$OUT"/..
ZIP="SFMonoNerdFontMono.zip"
zip -rq "$ZIP" "$(basename "$OUT")"
open .
echo "Done. Output: $OUT"
echo "Zip ready to AirDrop: $PWD/$ZIP"
