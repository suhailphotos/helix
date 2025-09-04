#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

# -----------------------------
# Flags
# -----------------------------
EXPL_REF=""          # --ref <git ref: tag/branch/sha>
EXPL_VERSION=""      # --version X.Y.Z  (we normalize to vX.Y.Z)
DEV_BRANCH=""        # --dev <branch>
LIMIT_HOST=""        # --limit <host>
OTHER_ARGS=()

print_usage() {
  cat <<'EOF'
Install desktop GUI apps via Ansible (macOS only).

Usage:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_macos_desktop_apps.sh)"

Options:
  --version X.Y.Z   Use tag vX.Y.Z
  --ref REF         Use an explicit git ref (tag/branch/sha)
  --dev BRANCH      Use a development branch (mutually exclusive with --version/--ref)
  --limit HOST      Limit to a host from inventory (auto-detected if omitted)
  -h, --help        Show help
EOF
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)     EXPL_REF="${2:-}"; shift ;;
    --version) EXPL_VERSION="${2:-}"; shift ;;
    --dev)     DEV_BRANCH="${2:-}"; shift ;;
    --limit)   LIMIT_HOST="${2:-}"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) OTHER_ARGS+=("$1") ;;
  esac
  shift
done

if [[ -n "$DEV_BRANCH" && ( -n "$EXPL_REF" || -n "$EXPL_VERSION" ) ]]; then
  echo "Use either --dev <branch> OR --ref/--version, not both." >&2
  exit 2
fi
if [[ -n "$EXPL_REF" && -n "$EXPL_VERSION" ]]; then
  echo "Use either --ref OR --version, not both." >&2
  exit 2
fi

# -----------------------------
# Helpers
# -----------------------------
keep_sudo_alive() {
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      echo "Requesting admin privileges…"
      sudo -v
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  fi
}

detect_brew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return 0
  fi
  return 1
}

ensure_brew_shellenv() {
  local brew_bin="$1"
  local zprof="$HOME/.zprofile"
  local line='eval "$('"$brew_bin"' shellenv)"'
  if ! grep -qxF "$line" "$zprof" 2>/dev/null; then
    { echo; echo "$line"; } >> "$zprof"
  fi
  eval "$("$brew_bin" shellenv)"
}

normalize_tag() {
  # turn 0.1.10 -> v0.1.10; keep v0.1.10 as-is
  local t="$1"
  if [[ "$t" =~ ^v ]]; then
    echo "$t"
  else
    echo "v$t"
  fi
}

latest_semver_tag() {
  # needs git (CLT provides it)
  git ls-remote --tags --refs https://github.com/suhailphotos/helix.git \
    | awk '{print $2}' \
    | sed 's#refs/tags/##' \
    | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -1
}

ref_exists_remote() {
  local ref="$1"
  git ls-remote --heads --tags https://github.com/suhailphotos/helix.git "$ref" | grep -q .
}

auto_limit_host() {
  local inv="$1"

  # if user gave --limit, respect it
  if [[ -n "$LIMIT_HOST" ]]; then
    echo "$LIMIT_HOST"
    return 0
  fi

  local cands=()
  cands+=("$(scutil --get ComputerName 2>/dev/null || true)")
  cands+=("$(scutil --get LocalHostName 2>/dev/null || true)")
  cands+=("$(hostname -s 2>/dev/null || true)")

  local raw h
  for raw in "${cands[@]}"; do
    h="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    [[ -z "$h" ]] && continue
    if grep -qiE "^[[:space:]]+${h}:[[:space:]]*$" "$inv"; then
      echo "$h"
      return 0
    fi
  done
  echo ""
}

checkout_ref() {
  # Robust shallow fetch of a tag/branch/sha, then checkout FETCH_HEAD
  local repo="$1"
  local dir="$2"
  local ref="$3"

  if [[ ! -d "$dir/.git" ]]; then
    mkdir -p "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo" 2>/dev/null || true
  fi

  if ! git -C "$dir" fetch --depth 1 --no-tags origin "$ref" --prune 2>/dev/null; then
    # If it might be a tag, try explicit tag refspec
    git -C "$dir" fetch --depth 1 --no-tags origin "refs/tags/$ref:refs/tags/$ref" --prune || true
  fi

  # Checkout whatever we just fetched, without relying on the ref name
  git -C "$dir" checkout -q --detach FETCH_HEAD || git -C "$dir" reset --hard -q FETCH_HEAD
}

# -----------------------------
# Resolve the desired ref
# -----------------------------
HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
CACHE_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_checkout}"

HELIX_REF=""
if   [[ -n "$DEV_BRANCH"   ]]; then HELIX_REF="$DEV_BRANCH"
elif [[ -n "$EXPL_REF"     ]]; then HELIX_REF="$EXPL_REF"
elif [[ -n "$EXPL_VERSION" ]]; then HELIX_REF="$(normalize_tag "$EXPL_VERSION")"
else
  HELIX_REF="$(latest_semver_tag || true)"
  [[ -n "$HELIX_REF" ]] || HELIX_REF="v0.1.10"
fi

if ! ref_exists_remote "$HELIX_REF"; then
  echo "Warning: ref '$HELIX_REF' not found remotely; trying as commit SHA…" >&2
fi

# -----------------------------
# macOS prerequisites
# -----------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is intended to be run on macOS." >&2
  exit 1
fi

# Xcode CLT includes git
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Run: xcode-select --install" >&2
  exit 1
fi

BREW_BIN="$(detect_brew || true)"
if [[ -z "$BREW_BIN" ]]; then
  keep_sudo_alive
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(detect_brew || true)"
  if [[ -z "$BREW_BIN" ]]; then
    echo "Homebrew installed but not found on standard paths." >&2
    exit 1
  fi
fi
ensure_brew_shellenv "$BREW_BIN"

if ! command -v ansible-playbook >/dev/null 2>&1; then
  "$BREW_BIN" install ansible
fi

# -----------------------------
# Fetch repo at chosen ref
# -----------------------------
checkout_ref "$HELIX_REPO_URL" "$CACHE_DIR" "$HELIX_REF"

ANS_DIR="$CACHE_DIR/ansible"
INV_FILE="$ANS_DIR/inventory.yml"
cd "$ANS_DIR"
export ANSIBLE_CONFIG="$ANS_DIR/ansible.cfg"

# Collections
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

AUTO_LIMIT="$(auto_limit_host "$INV_FILE")"

# Keep clones and raw file fetches consistent with the chosen ref
EXTRA_VARS=(
  -e "helix_repo_branch=$HELIX_REF"
  -e "helix_main_branch=$HELIX_REF"
  -e "helix_repo_raw_base=https://raw.githubusercontent.com/suhailphotos/helix/$HELIX_REF"
)

echo "==> Installing desktop apps (ref=$HELIX_REF) ${AUTO_LIMIT:+[limit:$AUTO_LIMIT]}"

cmd=( ansible-playbook -i "$INV_FILE" playbooks/desktop_apps.yml -K "${EXTRA_VARS[@]}" )
[[ -n "$AUTO_LIMIT" ]] && cmd+=( --limit "$AUTO_LIMIT" )
if [[ ${#OTHER_ARGS[@]:-0} -gt 0 ]]; then
  cmd+=( "${OTHER_ARGS[@]}" )
fi

"${cmd[@]}"

echo "🎉 Desktop apps done."
