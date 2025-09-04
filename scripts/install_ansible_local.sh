#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

# -----------------------------
# Flags
# -----------------------------
WITH_SF_FONTS=0
ONLY_SF_FONTS=0
RUN_ALL=0
RUN_POETRY=0
LIMIT_HOST="${LIMIT_HOST:-}"     # optional override
EXPL_REF=""                      # --ref <any git ref>
EXPL_VERSION=""                  # --version <semver or vX.Y.Z>
DEV_BRANCH=""                    # --dev <branch>
OTHER_ARGS=()

print_usage() {
  cat <<'EOF'
Usage examples

Default (latest stable tag):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"

Include SF fonts:
  ...install_ansible_local.sh" -- --sf_fonts

Only SF fonts:
  ...install_ansible_local.sh" -- --only_sf_fonts

All (base + fonts + poetry):
  ...install_ansible_local.sh" -- --all

Pin to a specific version:
  ...install_ansible_local.sh" -- --version 0.1.11
  # or --ref v0.1.11

Dev branch:
  ...install_ansible_local.sh" -- --dev feature/my-branch

Optional:
  --poetry
  --limit HOST
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf_fonts|--sf-fonts) WITH_SF_FONTS=1 ;;
    --only_sf_fonts|--fonts-only) WITH_SF_FONTS=1; ONLY_SF_FONTS=1 ;;
    --poetry) RUN_POETRY=1 ;;
    --all) RUN_ALL=1 ;;
    --limit) LIMIT_HOST="${2:-}"; shift ;;
    --ref) EXPL_REF="${2:-}"; shift ;;
    --version) EXPL_VERSION="${2:-}"; shift ;;
    --dev) DEV_BRANCH="${2:-}"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) OTHER_ARGS+=("$1") ;;
  esac
  shift
done
[[ "$RUN_ALL" -eq 1 ]] && { WITH_SF_FONTS=1; RUN_POETRY=1; }
if [[ "$ONLY_SF_FONTS" -eq 1 && "$RUN_POETRY" -eq 1 ]]; then
  echo "Refusing: --only_sf_fonts cannot be combined with --poetry (poetry needs base toolchain)." >&2
  exit 2
fi
if [[ -n "$DEV_BRANCH" && ( -n "$EXPL_REF" || -n "$EXPL_VERSION" ) ]]; then
  echo "Use either --dev <branch> OR --ref/--version, not both." >&2; exit 2
fi
if [[ -n "$EXPL_REF" && -n "$EXPL_VERSION" ]]; then
  echo "Use either --ref OR --version, not both." >&2; exit 2
fi

# -----------------------------
# Helpers
# -----------------------------
keep_sudo_alive() {
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      echo "Requesting admin privileges…"; sudo -v
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  fi
}
detect_brew() {
  [[ -x /opt/homebrew/bin/brew ]] && { echo /opt/homebrew/bin/brew; return; }
  [[ -x /usr/local/bin/brew  ]] && { echo /usr/local/bin/brew;  return; }
  return 1
}
ensure_brew_shellenv() {
  local brew_bin="$1"
  local zprof="$HOME/.zprofile"
  local line='eval "$('"$brew_bin"' shellenv)"'
  grep -qxF "$line" "$zprof" 2>/dev/null || { echo >> "$zprof"; echo "$line" >> "$zprof"; }
  eval "$("$brew_bin" shellenv)"
}
normalize_tag() { [[ "$1" =~ ^v ]] && echo "$1" || echo "v$1"; }
latest_semver_tag() {
  git ls-remote --tags --refs https://github.com/suhailphotos/helix.git \
    | awk '{print $2}' \
    | sed 's#refs/tags/##' \
    | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -1
}
ref_exists_remote() { git ls-remote --heads --tags https://github.com/suhailphotos/helix.git "$1" | grep -q .; }
auto_limit_host() {
  local inv="$1"
  [[ -n "$LIMIT_HOST" ]] && { echo "$LIMIT_HOST"; return 0; }
  local cands=()
  cands+=("$(scutil --get ComputerName 2>/dev/null || true)")
  cands+=("$(scutil --get LocalHostName 2>/dev/null || true)")
  cands+=("$(hostname -s 2>/dev/null || true)")
  for raw in "${cands[@]}"; do
    h="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    [[ -z "$h" ]] && continue
    if grep -qiE "^[[:space:]]+${h}:[[:space:]]*$" "$inv"; then echo "$h"; return 0; fi
  done
  echo ""
}
checkout_ref() {
  # Robust shallow fetch of a tag/branch/sha, then checkout FETCH_HEAD
  local repo="$1" dir="$2" ref="$3"
  if [[ ! -d "$dir/.git" ]]; then
    mkdir -p "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo" 2>/dev/null || true
  fi
  if ! git -C "$dir" fetch --depth 1 --no-tags origin "$ref" --prune 2>/dev/null; then
    # try explicit tag refspec if the above fails
    git -C "$dir" fetch --depth 1 --no-tags origin "refs/tags/$ref:refs/tags/$ref" --prune || true
  fi
  git -C "$dir" checkout -q --detach FETCH_HEAD || git -C "$dir" reset --hard -q FETCH_HEAD
}

# -----------------------------
# Resolve ref
# -----------------------------
HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
CACHE_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_checkout}"

if   [[ -n "$DEV_BRANCH"   ]]; then HELIX_REF="$DEV_BRANCH"
elif [[ -n "$EXPL_REF"     ]]; then HELIX_REF="$EXPL_REF"
elif [[ -n "$EXPL_VERSION" ]]; then HELIX_REF="$(normalize_tag "$EXPL_VERSION")"
else
  HELIX_REF="$(latest_semver_tag || true)"; [[ -n "$HELIX_REF" ]] || HELIX_REF="v0.1.10"
fi
ref_exists_remote "$HELIX_REF" || echo "Warning: ref '$HELIX_REF' not found remotely; trying as commit SHA…" >&2

# -----------------------------
# macOS prerequisites
# -----------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  xcode-select -p >/dev/null 2>&1 || { echo "Xcode CLT missing. Run: xcode-select --install" >&2; exit 1; }
  BREW_BIN="$(detect_brew || true)"
  if [[ -z "$BREW_BIN" ]]; then
    keep_sudo_alive
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW_BIN="$(detect_brew || true)" || { echo "Homebrew installed but not found on standard paths." >&2; exit 1; }
  fi
  ensure_brew_shellenv "$BREW_BIN"
  command -v ansible-playbook >/dev/null 2>&1 || "$BREW_BIN" install ansible
else
  command -v ansible-playbook >/dev/null 2>&1 || { echo "Install Ansible first." >&2; exit 1; }
fi

# -----------------------------
# Fetch repo at chosen ref
# -----------------------------
checkout_ref "$HELIX_REPO_URL" "$CACHE_DIR" "$HELIX_REF"
ANS_DIR="$CACHE_DIR/ansible"
INV_FILE="$ANS_DIR/inventory.yml"
cd "$ANS_DIR"
export ANSIBLE_CONFIG="$ANS_DIR/ansible.cfg"
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

AUTO_LIMIT="$(auto_limit_host "$INV_FILE")"

# Keep clones and raw file fetches consistent with the chosen ref
EXTRA_VARS=(
  -e "helix_repo_branch=$HELIX_REF"
  -e "helix_main_branch=$HELIX_REF"
  -e "helix_repo_raw_base=https://raw.githubusercontent.com/suhailphotos/helix/$HELIX_REF"
)

# ---- Run base play
play_cmd=( ansible-playbook -i "$INV_FILE" playbooks/macos_local.yml -K "${EXTRA_VARS[@]}" )
[[ -n "$AUTO_LIMIT"    ]] && play_cmd+=( --limit "$AUTO_LIMIT" )
[[ "$WITH_SF_FONTS" -eq 1 ]] && play_cmd+=( -e enable_sf_fonts=true )
[[ "$ONLY_SF_FONTS" -eq 1 ]] && play_cmd+=( --tags fonts )

echo "==> macOS bootstrap (ref=$HELIX_REF) ${ONLY_SF_FONTS:+[fonts only]} ${AUTO_LIMIT:+[limit:$AUTO_LIMIT]}"
if ((${#OTHER_ARGS[@]:-0})); then
  "${play_cmd[@]}" "${OTHER_ARGS[@]}"
else
  "${play_cmd[@]}"
fi

# ---- Optional Poetry play
if [[ "$RUN_POETRY" -eq 1 ]]; then
  poetry_cmd=( ansible-playbook -i "$INV_FILE" playbooks/poetry_envs.yml -K "${EXTRA_VARS[@]}" )
  [[ -n "$AUTO_LIMIT" ]] && poetry_cmd+=( --limit "$AUTO_LIMIT" )
  echo "==> Poetry envs (ref=$HELIX_REF) ${AUTO_LIMIT:+[limit:$AUTO_LIMIT]}"
  "${poetry_cmd[@]}"
fi

echo "🎉 Done."
