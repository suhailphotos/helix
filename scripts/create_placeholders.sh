#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix}"
cd "$ROOT"

header() {
  printf "# placeholder — managed by helix/dotfiles\n# safe to leave empty; defaults still apply\n\n"
}

mkfile() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ]; then
    header > "$path"
    echo "created: $path"
  else
    echo "exists:  $path"
  fi
}

mkkeep() {
  local dir="$1"
  mkdir -p "$dir"
  local keep="$dir/.keep"
  [ -f "$keep" ] || { echo "placeholder to keep dir in git" > "$keep"; echo "created: $keep"; }
}

# Empty-but-safe config files
mkfile dotfiles/git/.config/git/config
mkfile dotfiles/ripgrep/.config/ripgrep/ripgreprc
mkfile dotfiles/fzf/.config/fzf/fzf.zsh
mkfile dotfiles/bat/.config/bat/config
mkfile dotfiles/tealdeer/.config/tealdeer/config.toml
mkfile dotfiles/wget/.config/wget/wgetrc
mkfile dotfiles/curl/.config/curlrc
mkfile dotfiles/npm/.config/npm/npmrc
mkfile dotfiles/stow/.stowrc
mkfile dotfiles/gawk/.awkrc
mkfile dotfiles/pip/.config/pip/pip.conf

# Directories to keep (let app generate real files later)
mkkeep dotfiles/btop/.config/btop
mkkeep dotfiles/mc/.config/mc
mkkeep dotfiles/zoxide/.config/zoxide

# Optional: a delta snippet you can include later from git
mkfile dotfiles/git/.config/git/delta.gitconfig

# Optional: jq library folder (no rc file, but keep a spot for shared filters)
mkdir -p dotfiles/jq/.jq
[ -f dotfiles/jq/.jq/README.md ] || {
  printf "Place reusable jq filters here. jq searches ~/.jq by default.\n" > dotfiles/jq/.jq/README.md
  echo "created: dotfiles/jq/.jq/README.md"
}

echo "Done."
