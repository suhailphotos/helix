#!/usr/bin/env bash
set -euo pipefail
exec </dev/null

PACKAGES_ROOT="${PACKAGES_ROOT:-/Users/suhail/Library/CloudStorage/Dropbox/matrix/packages}"
HELIX_ROOT="${HELIX_ROOT:-/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-poetry2uv}"

# Only migrate these now (others left for later, per your notes)
MIGRATE_PKGS=(
  ocioTools
)

create_branch_push () {
  local repo="$1"
  [[ -d "$repo/.git" ]] || { echo "⚠️  Skipping (not a git repo): $repo"; return 0; }
  ( cd "$repo"
    git fetch --all --tags --prune
    git switch main
    git pull --ff-only "$REMOTE" main || true
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
      echo "• $repo already has $BRANCH"
    else
      git switch -c "$BRANCH"
      echo "• Created $BRANCH in $repo"
    fi
    git push -u "$REMOTE" "$BRANCH" || true
  )
}

echo "==> Creating branches for selected packages…"
for p in "${MIGRATE_PKGS[@]}"; do
  create_branch_push "$PACKAGES_ROOT/$p"
done

echo "==> Creating branch for helix…"
create_branch_push "$HELIX_ROOT"

echo "✅ Done."
