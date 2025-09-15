#!/usr/bin/env bash
set -euo pipefail

# Root to scan; pass a path as $1 to override
ROOT="${1:-$HOME/Library/CloudStorage/Dropbox/matrix/packages}"

FP_ATTR='com.apple.fileprovider.ignore#P'  # current macOS/Dropbox File Provider
LEG_ATTR='com.dropbox.ignored'             # legacy fallback

# Walk all .venv dirs; handle spaces safely with -print0 / -d ''.
find "$ROOT" -type d -name .venv -print0 | \
while IFS= read -r -d '' d; do
  if [[ "$d" == "$HOME"/Library/CloudStorage/Dropbox/* ]]; then
    # Prefer File Provider key; fall back to legacy if needed
    if xattr -w "$FP_ATTR" 1 "$d" 2>/dev/null; then
      echo "✓ ignored (FP): $d"
    elif xattr -w "$LEG_ATTR" 1 "$d" 2>/dev/null; then
      echo "✓ ignored (legacy): $d"
    else
      echo "✗ failed to set ignore: $d" >&2
    fi
  else
    # Not in Dropbox folder; nothing to do
    echo "… not a Dropbox path, skipped: $d"
  fi
done
