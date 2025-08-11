#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR

# Detach stdin so no subcommand eats the rest of this script when piped via curl.
exec </dev/null

# -----------------------------
# Flags / defaults
# -----------------------------
HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_bootstrap}"

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
USE_1PASSWORD=0                      # if 1 -> uncomment IdentityAgent in base; omit IdentityFile in snippets
INCLUDE_MACOS=0                      # if 1 -> include macOS group too
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-}" # e.g. "suhail.tech" to turn "nimbus" -> "nimbus.suhail.tech" if no ansible_host
DEFAULT_USER="${DEFAULT_USER:-$USER}"
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/id_rsa}"  # ignored when USE_1PASSWORD=1
DRY_RUN=0

print_usage() {
  cat <<'EOF'
Generate ~/.ssh/config and per-host snippets from your Ansible inventory.

Examples
  # Linux only, on-disk key (~/.ssh/id_rsa)
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash

  # Include macOS hosts as well
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash -s -- --include-macos

  # Prefer 1Password SSH agent (uncomment IdentityAgent; omit IdentityFile in snippets)
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash -s -- --use-1password

  # Provide a default DNS suffix for hosts without ansible_host
  bash ssh_config_local.sh --default-domain suhail.tech

Flags
  --include-macos           Include hosts in the "macos" group
  --use-1password           Uncomment IdentityAgent in base; omit IdentityFile in snippets
  --default-domain DOMAIN   Append DOMAIN to hostnames missing ansible_host
  --identity-file PATH      IdentityFile for hosts (default: ~/.ssh/id_rsa) [ignored with --use-1password]
  --default-user USER       Default SSH user if not specified in inventory (default: $USER)
  --dry-run                 Print what would be written, don’t touch files
  -h, --help                Show help
EOF
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-macos) INCLUDE_MACOS=1 ;;
    --use-1password) USE_1PASSWORD=1 ;;
    --default-domain) DEFAULT_DOMAIN="${2:-}"; shift ;;
    --identity-file) IDENTITY_FILE="${2:-}"; shift ;;
    --default-user) DEFAULT_USER="${2:-}"; shift ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown flag: $1" >&2; print_usage; exit 2 ;;
  esac
  shift
done

# -----------------------------
# Locate repo & inventory.yml
# -----------------------------
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  PARENT_DIR=""
fi

if [[ -n "$PARENT_DIR" && -f "$PARENT_DIR/ansible/inventory.yml" ]]; then
  REPO_ROOT="$PARENT_DIR"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Please install Xcode CLT: xcode-select --install" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$HELIX_LOCAL_DIR")"
  if [[ -d "$HELIX_LOCAL_DIR/.git" ]]; then
    echo "==> Updating helix in $HELIX_LOCAL_DIR (branch: $HELIX_BRANCH)"
    git -C "$HELIX_LOCAL_DIR" fetch --quiet
    git -C "$HELIX_LOCAL_DIR" checkout "$HELIX_BRANCH" --quiet
    git -C "$HELIX_LOCAL_DIR" pull --ff-only --quiet
  else
    echo "==> Cloning helix into $HELIX_LOCAL_DIR"
    git clone --depth 1 --branch "$HELIX_BRANCH" --quiet "$HELIX_REPO_URL" "$HELIX_LOCAL_DIR"
  fi
  REPO_ROOT="$HELIX_LOCAL_DIR"
fi

INVENTORY="$REPO_ROOT/ansible/inventory.yml"
if [[ ! -f "$INVENTORY" ]]; then
  echo "Inventory not found at $INVENTORY" >&2
  exit 1
fi

# -----------------------------
# Need yq
# -----------------------------
if ! command -v yq >/dev/null 2>&1; then
  echo "This script needs 'yq'. Run your Ansible bootstrap first, or: brew install yq" >&2
  exit 1
fi

# -----------------------------
# Prepare ~/.ssh layout
# -----------------------------
mkdir -p "$SSH_DIR/config.d"
chmod 700 "$SSH_DIR" "$SSH_DIR/config.d"

BASE_CFG="$SSH_DIR/config"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -f "$BASE_CFG" && $DRY_RUN -eq 0 ]]; then
  cp "$BASE_CFG" "$BASE_CFG.bak.$TIMESTAMP"
fi

# Your standard base config (with IdentityAgent commented)
BASE_STANDARD="$(cat <<'STD'
# Managed by helix ssh_config_local.sh

Host *
  # Quality of life
  AddKeysToAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes

  # Connection multiplexing (faster repeated SSH/scp)
  ControlMaster auto
  ControlPersist 10m
  ControlPath ~/.ssh/cm-%r@%h:%p

  # Host key handling (use ask for strict checking; or accept-new if you trust LAN)
  StrictHostKeyChecking ask
  UserKnownHostsFile ~/.ssh/known_hosts

  # If you use 1Password SSH agent, uncomment:
  # IdentityAgent ~/.1password/agent.sock

# Pull in all host snippets
Include ~/.ssh/config.d/*.conf
STD
)"

# If --use-1password, uncomment the IdentityAgent line
if [[ $USE_1PASSWORD -eq 1 ]]; then
  BASE_CONTENT="$(printf "%s\n" "$BASE_STANDARD" \
    | sed 's/^  # IdentityAgent \(~\/\.1password\/agent\.sock\)$/  IdentityAgent \1/')"
else
  BASE_CONTENT="$BASE_STANDARD"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "---- would write $BASE_CFG ----"
  printf "%s\n" "$BASE_CONTENT"
else
  printf "%s" "$BASE_CONTENT" > "$BASE_CFG"
  chmod 600 "$BASE_CFG"
fi

# -----------------------------
# Parse inventory -> rows of: group \t host \t ansible_host \t ansible_user \t identity_file
# -----------------------------
YQ_QUERY='.all.children | to_entries[] | . as $grp
  | ($grp.value.hosts // {}) | to_entries[]
  | [ $grp.key, .key, (.value.ansible_host // ""), (.value.ansible_user // ""), (.value.identity_file // "") ]
  | @tsv'

# Iterate and create per-host snippets
while IFS=$'\t' read -r group host ans_host ans_user ans_identity; do
  [[ -z "${host:-}" ]] && continue

  # Filter groups
  if [[ "$group" == "macos" && $INCLUDE_MACOS -ne 1 ]]; then
    continue
  fi

  # HostName resolution
  host_name="$ans_host"
  if [[ -z "$host_name" ]]; then
    if [[ -n "$DEFAULT_DOMAIN" ]]; then
      host_name="${host}.${DEFAULT_DOMAIN}"
    else
      host_name="$host"
    fi
  fi

  # User & Identity
  user="${ans_user:-$DEFAULT_USER}"
  ident="${ans_identity:-$IDENTITY_FILE}"

  CONF_PATH="$SSH_DIR/config.d/${host}.conf"

  CONTENT="Host ${host}
  HostName ${host_name}
  User ${user}
"
  if [[ $USE_1PASSWORD -eq 0 ]]; then
    CONTENT+="  IdentityFile ${ident}\n"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $CONF_PATH ----"
    printf "%b" "$CONTENT"
  else
    printf "%b" "$CONTENT" > "$CONF_PATH"
    chmod 600 "$CONF_PATH"
  fi

done < <(yq -r "$YQ_QUERY" "$INVENTORY")

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete. No files changed."
else
  echo "SSH config generated:"
  echo "   - Base: $BASE_CFG"
  echo "   - Snippets: $SSH_DIR/config.d/*.conf"
  echo "Tip: test with 'ssh -v nimbus' (or any host)."
fi
