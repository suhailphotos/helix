#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

EXPL_REF=""; EXPL_VERSION=""; DEV_BRANCH=""
PASSTHRU_LIMIT=""
OTHER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) EXPL_REF="${2:-}"; shift ;;
    --version) EXPL_VERSION="${2:-}"; shift ;;
    --dev) DEV_BRANCH="${2:-}"; shift ;;
    --limit) PASSTHRU_LIMIT="${2:-}"; OTHER_ARGS+=("$1" "$2"); shift ;;
    --) shift; break ;;
    *) OTHER_ARGS+=("$1") ;;
  esac
  shift
done
if [[ -n "$DEV_BRANCH" && ( -n "$EXPL_REF" || -n "$EXPL_VERSION" ) ]]; then
  echo "Use either --dev <branch> OR --ref/--version, not both." >&2; exit 2
fi
if [[ -n "$EXPL_REF" && -n "$EXPL_VERSION" ]]; then
  echo "Use either --ref OR --version, not both." >&2; exit 2
fi

ensure_brew_shellenv(){ local b="$1"; local z="$HOME/.zprofile"; local line='eval "$('"$b"' shellenv)"'; grep -qxF "$line" "$z" 2>/dev/null || { echo >> "$z"; echo "$line" >> "$z"; }; eval "$("$b" shellenv)"; }
detect_brew(){ [[ -x /opt/homebrew/bin/brew ]] && { echo /opt/homebrew/bin/brew; return; }; [[ -x /usr/local/bin/brew ]] && { echo /usr/local/bin/brew; return; }; return 1; }
normalize_tag(){ [[ "$1" =~ ^v ]] && echo "$1" || echo "v$1"; }
latest_semver_tag(){ git ls-remote --tags --refs https://github.com/suhailphotos/helix.git | awk '{print $2}' | sed 's#refs/tags/##' | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1; }
ref_exists_remote(){ git ls-remote --heads --tags https://github.com/suhailphotos/helix.git "$1" | grep -q .; }
auto_limit_host(){ local inv="$1"; local cands=(); cands+=("$(scutil --get ComputerName 2>/dev/null || true)"); cands+=("$(scutil --get LocalHostName 2>/dev/null || true)"); cands+=("$(hostname -s 2>/dev/null || true)"); for raw in "${cands[@]}"; do h="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"; [[ -z "$h" ]] && continue; if grep -qiE "^[[:space:]]+${h}:[[:space:]]*$" "$inv"; then echo "$h"; return 0; fi; done; echo ""; }
checkout_ref(){ local repo="$1" dir="$2" ref="$3"; if [[ ! -d "$dir/.git" ]]; then mkdir -p "$dir"; git init -q "$dir"; git -C "$dir" remote add origin "$repo" 2>/dev/null || true; fi; if ! git -C "$dir" fetch --depth 1 --no-tags origin "$ref" --prune 2>/dev/null; then git -C "$dir" fetch --depth 1 --no-tags origin "refs/tags/$ref:refs/tags/$ref" --prune || true; fi; git -C "$dir" checkout -q --detach FETCH_HEAD || git -C "$dir" reset --hard -q FETCH_HEAD; }

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
CACHE_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_checkout}"

# Resolve ref (default = latest tag)
if   [[ -n "$DEV_BRANCH"   ]]; then HELIX_REF="$DEV_BRANCH"
elif [[ -n "$EXPL_REF"     ]]; then HELIX_REF="$EXPL_REF"
elif [[ -n "$EXPL_VERSION" ]]; then HELIX_REF="$(normalize_tag "$EXPL_VERSION")"
else HELIX_REF="$(latest_semver_tag || true)"; [[ -n "$HELIX_REF" ]] || HELIX_REF="v0.1.10"
fi
ref_exists_remote "$HELIX_REF" || echo "Warning: ref '$HELIX_REF' not found remotely; trying as commit SHA…" >&2

# macOS: ensure brew/ansible; Linux: require ansible installed
if [[ "$(uname -s)" == "Darwin" ]]; then
  xcode-select -p >/dev/null 2>&1 || { echo "Xcode CLT missing. Run: xcode-select --install" >&2; exit 1; }
  BREW_BIN="$(detect_brew || true)"
  if [[ -z "$BREW_BIN" ]]; then
    echo "Requesting admin privileges…"; sudo -v || true
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW_BIN="$(detect_brew || true)" || { echo "Homebrew installed but not found on standard paths." >&2; exit 1; }
  fi
  ensure_brew_shellenv "$BREW_BIN"
  command -v ansible-playbook >/dev/null 2>&1 || "$BREW_BIN" install ansible
else
  command -v ansible-playbook >/dev/null 2>&1 || { echo "Ansible not found. Please install it first." >&2; exit 1; }
fi

checkout_ref "$HELIX_REPO_URL" "$CACHE_DIR" "$HELIX_REF"
ANS_DIR="$CACHE_DIR/ansible"; INV_FILE="$ANS_DIR/inventory.yml"
cd "$ANS_DIR"; export ANSIBLE_CONFIG="$ANS_DIR/ansible.cfg"
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

AUTO_LIMIT=""
if [[ "$(uname -s)" == "Darwin" && -z "${PASSTHRU_LIMIT:-}" ]]; then
  AUTO_LIMIT="$(auto_limit_host "$INV_FILE")"
fi

EXTRA_VARS=( -e "helix_repo_branch=$HELIX_REF" -e "helix_main_branch=$HELIX_REF" -e "helix_repo_raw_base=https://raw.githubusercontent.com/suhailphotos/helix/$HELIX_REF" )

echo "==> Building Poetry envs (ref=$HELIX_REF) ${PASSTHRU_LIMIT:+[limit:$PASSTHRU_LIMIT]} ${AUTO_LIMIT:+[limit:$AUTO_LIMIT]}"
cmd=( ansible-playbook -i "$INV_FILE" playbooks/poetry_envs.yml -K "${EXTRA_VARS[@]}" )
[[ -n "$PASSTHRU_LIMIT" ]] && cmd+=( --limit "$PASSTHRU_LIMIT" )
[[ -n "$AUTO_LIMIT"     ]] && cmd+=( --limit "$AUTO_LIMIT" )
if ((${#OTHER_ARGS[@]:-0})); then
  "${cmd[@]}" "${OTHER_ARGS[@]}"
else
  "${cmd[@]}"
fi

echo "🎉 Poetry envs done."
