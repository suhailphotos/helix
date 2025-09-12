#!/usr/bin/env bash
set -euo pipefail

ts="$(date +%Y%m%d-%H%M%S)"

# Configure these if you want SSH or a host-specific branch:
BINDU_REMOTE="${BINDU_REMOTE:-https://github.com/suhailphotos/bindu.git}"
BINDU_BRANCH="${BINDU_BRANCH:-main}"

CFG="$HOME/.config"

echo "==> Backup $CFG → $HOME/.config.backup.$ts.tar.gz"
tar -C "$HOME" -czf "$HOME/.config.backup.$ts.tar.gz" .config 2>/dev/null || true

# 1) Old HELIX worktree clean-up (if any)
if [ -d "$HOME/.helix/.git" ]; then
  echo "==> Detaching HELIX worktree (if present)"
  git -C "$HOME/.helix" worktree remove -f "$CFG" 2>/dev/null || true
  rm -rf "$HOME/.helix"
fi

# 2) Old BINDU host-repo worktree clean-up (if you ever used ~/.bindu)
if [ -d "$HOME/.bindu/.git" ]; then
  echo "==> Detaching BINDU worktree registered in ~/.bindu (if present)"
  git -C "$HOME/.bindu" worktree remove -f "$CFG" 2>/dev/null || true
  rm -rf "$HOME/.bindu"
fi

# 3) If ~/.config is a registered worktree from any parent, remove it cleanly
if [ -f "$CFG/.git" ] && grep -q '^gitdir: ' "$CFG/.git"; then
  gitdir="$(sed -n 's/^gitdir: //p' "$CFG/.git")"
  parent="$(dirname "$(dirname "$(dirname "$gitdir")")")"  # .../.git/worktrees/.config → repo root
  if [ -d "$parent/.git" ]; then
    echo "==> Removing worktree registration from $parent"
    git -C "$parent" worktree remove -f "$CFG" 2>/dev/null || true
  fi
fi

# 4) If ~/.config is an existing repo, check whether it's already Bindu
if [ -d "$CFG/.git" ] && [ ! -f "$CFG/.git" ]; then
  echo "==> Existing repo detected in $CFG"
  existing_origin="$(git -C "$CFG" remote get-url origin 2>/dev/null || echo '')"
  if [ "$existing_origin" != "$BINDU_REMOTE" ]; then
    echo "==> Moving aside non-Bindu repo"
    mv "$CFG" "$CFG.pre-bindu.$ts"
  fi
fi

# 5) Ensure ~/.config is a fresh clone of Bindu on desired branch
if [ ! -d "$CFG/.git" ] || [ -f "$CFG/.git" ]; then
  echo "==> Fresh clone of Bindu → $CFG (branch: $BINDU_BRANCH)"
  rm -rf "$CFG"
  git clone --depth 1 --branch "$BINDU_BRANCH" "$BINDU_REMOTE" "$CFG"
else
  echo "==> Switching $CFG to $BINDU_BRANCH and fast-forwarding"
  git -C "$CFG" fetch origin
  git -C "$CFG" checkout "$BINDU_BRANCH"
  git -C "$CFG" branch --set-upstream-to "origin/$BINDU_BRANCH" "$BINDU_BRANCH" || true
  git -C "$CFG" pull --ff-only
fi

# 6) QoL: ignore macOS metadata
# echo '**/.DS_Store' >> "$CFG/.gitignore" 2>/dev/null || true

echo "==> Done. Current repo:"
git -C "$CFG" remote -v
git -C "$CFG" status -sb
