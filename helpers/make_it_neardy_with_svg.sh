#!/usr/bin/env bash
set -euo pipefail

############################################
# Config: your SVG + fixed codepoint U+EE34
############################################

SVG_PATH="/Users/suhail/Downloads/feather-icon.svg"

REPO="$HOME/src/nerd-fonts"
OUT="$HOME/fonts-out/SFMonoNerdFontMono"
TMP="$HOME/fonts-out/tmp_sfmono_fix"

CUSTOM_FONT_DIR="$HOME/fonts-out/suhail-icons"
CUSTOM_FONT="$CUSTOM_FONT_DIR/SuhailIcons.ttf"

############################################
# Prereqs
############################################

brew list --versions fontforge >/dev/null 2>&1 || brew install fontforge
brew list --versions git        >/dev/null 2>&1 || brew install git

mkdir -p "$(dirname "$REPO")" "$OUT" "$TMP" "$CUSTOM_FONT_DIR"

if [ ! -f "$SVG_PATH" ]; then
  echo "ERROR: SVG file not found at: $SVG_PATH" >&2
  exit 1
fi

############################################
# 1) Build tiny custom icon font from SVG
############################################

echo "Creating custom icon font from: $SVG_PATH"

fontforge -lang=ff -c '
  svg = $1
  out = $2

  Print("  New font from SVG:", svg)
  New()
  Reencode("unicode")
  ScaleToEm(1000, 0)

  # Hard-coded to U+EE34
  Select(0uEE34)

  Import(svg)
  SetWidth(1024)

  SetFontNames("SuhailIcons", "Suhail Icons", "Suhail Icons")
  Generate(out)
  Close()
' "$SVG_PATH" "$CUSTOM_FONT"

echo "Custom icon font written to: $CUSTOM_FONT"

############################################
# 2) Get / update Nerd Fonts patcher
############################################

if [ ! -d "$REPO/.git" ]; then
  echo "Cloning nerd-fonts (shallow)…"
  git clone --depth=1 https://github.com/ryanoasis/nerd-fonts "$REPO"
else
  echo "Updating nerd-fonts (git pull, no re-clone)…"
  (cd "$REPO" && git pull --ff-only || true)
fi

############################################
# 3) Patch SF Mono with Nerd Fonts + custom
############################################

echo "Finding SF Mono faces…"

find /Library/Fonts "$HOME/Library/Fonts" /System/Library/Fonts \
  -maxdepth 1 -type f -iname "SF-Mono-*.otf" -print0 2>/dev/null |
while IFS= read -r -d "" SRC; do
  BASE="$(basename "$SRC" .otf)"
  FIXED="$TMP/${BASE}.ttf"

  echo "  Converting + clearing FS flags: $BASE -> $(basename "$FIXED")"
  fontforge -lang=ff -c '
    Open($1)
    SetOS2Value("FSType", 0)
    Generate($2)
    Close()
  ' "$SRC" "$FIXED"

  echo "  Patching with Nerd Fonts + custom glyph: $(basename "$FIXED")"
  fontforge -script "$REPO/font-patcher" \
    --complete \
    --mono \
    --careful \
    --custom "$CUSTOM_FONT" \
    "$FIXED" --outputdir "$OUT"
done

############################################
# 4) Prune faces + zip for AirDrop
############################################

echo "Pruning uncommon faces…"
cd "$OUT"
ls | grep -Ev "Regular|Bold|Italic|Medium|Semibold" | xargs -I{} rm -f "{}" || true
cd - >/dev/null

cd "$OUT"/..
ZIP="SFMonoNerdFontMono.zip"
zip -rq "$ZIP" "$(basename "$OUT")"

echo
echo "Done."
echo "Patched fonts directory: $OUT"
echo "Zip ready to AirDrop:    $PWD/$ZIP"
