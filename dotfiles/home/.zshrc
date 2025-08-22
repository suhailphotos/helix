# --- Optional: p10k instant prompt if Starship is missing ---
# (Instant prompt must be at top; only do it when starship isn't present.)
if ! command -v starship >/dev/null 2>&1; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi


# --- Orbit (cross-platform) ---
export ORBIT_HOME="${HOME}/.orbit"
export ORBIT_REMOTE="https://github.com/suhailphotos/orbit.git"
export ORBIT_BRANCH="main"

# First-time install
if [[ ! -d "$ORBIT_HOME/.git" ]]; then
  git clone --depth 1 --branch "$ORBIT_BRANCH" --quiet "$ORBIT_REMOTE" "$ORBIT_HOME" >/dev/null 2>&1
fi

# Silent, disowned background update
if command -v git >/dev/null && [[ -d "$ORBIT_HOME/.git" ]]; then
  (
    git -C "$ORBIT_HOME" fetch --quiet
    git -C "$ORBIT_HOME" merge --ff-only "origin/$ORBIT_BRANCH" --quiet
  ) >/dev/null 2>&1 &!
fi

# Source Orbit
source "$ORBIT_HOME/core/bootstrap.zsh"

