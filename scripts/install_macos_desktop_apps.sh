#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
CACHE_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_checkout}"

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
  if [[ -x /opt/homebrew/bin/brew ]]; then echo /opt/homebrew/bin/brew; return 0; fi
  if [[ -x /usr/local/bin/brew ]]; then echo /usr/local/bin/brew; return 0; fi
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
auto_limit_host() {
  local inv="$1"
  local cands=()
  cands+=("$(scutil --get ComputerName 2>/dev/null || true)")
  cands+=("$(scutil --get LocalHostName 2>/dev/null || true)")
  cands+=("$(hostname -s 2>/dev/null || true)")
  for raw in "${cands[@]}"; do
    h="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    [[ -z "$h" ]] && continue
    if grep -qiE "^[[:space:]]+${h}:[[:space:]]*$" "$inv"; then
      echo "$h"; return 0
    fi
  done
  echo ""
}

# Xcode CLT
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Run: xcode-select --install"
  exit 1
fi

# Homebrew (path-first detection; install only if truly missing)
BREW_BIN="$(detect_brew || true)"
if [[ -z "$BREW_BIN" ]]; then
  keep_sudo_alive
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(detect_brew || true)"
  [[ -n "$BREW_BIN" ]] || { echo "Homebrew installed but not found on standard paths." >&2; exit 1; }
fi
ensure_brew_shellenv "$BREW_BIN"

# Ansible
if ! command -v ansible-playbook >/dev/null 2>&1; then
  "$BREW_BIN" install ansible
fi

# Repo cache/update
if [[ ! -d "$CACHE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --depth 1 --branch "$HELIX_BRANCH" "$HELIX_REPO_URL" "$CACHE_DIR"
else
  git -C "$CACHE_DIR" fetch --prune origin
  git -C "$CACHE_DIR" reset --hard "origin/$HELIX_BRANCH"
fi

ANS_DIR="$CACHE_DIR/ansible"
INV_FILE="$ANS_DIR/inventory.yml"

cd "$ANS_DIR"
export ANSIBLE_CONFIG="$ANS_DIR/ansible.cfg"
ansible-galaxy collection install -r "$ANS_DIR/collections/requirements.yml" || true

AUTO_LIMIT="$(auto_limit_host "$INV_FILE")"

echo "==> Installing macOS desktop apps ${AUTO_LIMIT:+(limit=$AUTO_LIMIT)}"
ansible-playbook -i "$INV_FILE" playbooks/desktop_apps.yml -K \
  ${AUTO_LIMIT:+--limit "$AUTO_LIMIT"}

echo "🎉 Desktop apps done."
