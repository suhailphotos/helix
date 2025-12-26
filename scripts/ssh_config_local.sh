#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
exec </dev/null

# -----------------------------
# Flags / defaults
# -----------------------------
HELIX_REPO_URL="${HELIX_REPO_URL:-https://github.com/suhailphotos/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-main}"
HELIX_LOCAL_DIR="${HELIX_LOCAL_DIR:-$HOME/.cache/helix_bootstrap}"
FORCE_1P_AGENT_CONFIG=0
FORWARD_AGENT_ALL=0
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

# Keep the SSH ControlMaster alive for long stretches (e.g. 12h or 24h)
CONTROL_PERSIST="${CONTROL_PERSIST:-12h}"
# Keep all mux control sockets in a dedicated folder to avoid clutter
CONTROL_DIR="${CONTROL_DIR:-$SSH_DIR/controlpath}"

USE_1PASSWORD=0                      # if 1 -> uncomment IdentityAgent in base; omit IdentityFile in snippets
INCLUDE_MACOS=0                      # if 1 -> include macOS group too (legacy behavior)
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-}" # e.g. "suhail.tech" to turn "nimbus" -> "nimbus.suhail.tech" if no ansible_host
DEFAULT_USER="${DEFAULT_USER:-$USER}"
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/id_rsa}"  # ignored when USE_1PASSWORD=1
DRY_RUN=0

# Behavior toggles
REFRESH=0                            # overwrite existing per-host files only when --refresh
ONLY_LIST=""                         # limit to specific hosts: --only wisp,quasar

# GitHub / 1Password helpers
GITHUB_1PASSWORD=0
INSTALL_1P_AGENT_CONFIG=0
GITHUB_ADD_KEY=0

# NEW: classic GitHub key (Linux, no 1Password agent)
GITHUB_KEY=0
GITHUB_KEY_PATH="${GITHUB_KEY_PATH:-$HOME/.ssh/id_github}"


print_usage() {
  cat <<'EOF'
Generate ~/.ssh/config and per-host snippets from your Ansible inventory.

Examples
  # Linux only, on-disk key (~/.ssh/id_rsa)
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash

  # Include macOS hosts as well
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash -s -- --include-macos

  # Prefer 1Password SSH agent (uncomment IdentityAgent in base; omit IdentityFile in snippets)
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash -s -- --use-1password

  # Provide a default DNS suffix for hosts without ansible_host
  bash ssh_config_local.sh --default-domain suhail.tech

  # GitHub via 1Password (symlink + snippet), install agent.toml, and add GitHub key
  curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh | bash -s -- \
    --include-macos --github-1password --install-1p-agent-config --github-add-key

Flags
  --include-macos               Include hosts in the "macos" group
  --use-1password               Uncomment IdentityAgent in base; omit IdentityFile in snippets
  --default-domain DOMAIN       Append DOMAIN to hostnames missing ansible_host
  --identity-file PATH          IdentityFile for hosts (default: ~/.ssh/id_rsa) [ignored with --use-1password]
  --default-user USER           Default SSH user if not specified in inventory (default: $USER)
  --dry-run                     Print what would be written, don’t touch files
  --forward-agent               Add 'ForwardAgent yes' to all generated host snippets
  --refresh                     Overwrite existing per-host files (default: preserve)
  --only LIST                   Comma-separated hostnames to generate (e.g., --only wisp,quasar)

  # GitHub / 1Password
  --github-1password            Create ~/.1password/agent.sock symlink (macOS) and write ~/.ssh/config.d/10-github.conf
  --install-1p-agent-config     Copy ~/.config/.../agent.toml to 1Password's sandbox path and chmod 600 (macOS)
  --github-add-key              Add "op://security/GitHub/public key" to your GitHub account (idempotent)
  --github-key PATH              Write Host github.com using IdentityFile PATH (e.g. ~/.ssh/id_github)

  -h, --help                    Show help
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
    --forward-agent) FORWARD_AGENT_ALL=1 ;;
    --refresh) REFRESH=1 ;;
    --only) ONLY_LIST="${2:-}"; shift ;;
    --github-1password) GITHUB_1PASSWORD=1 ;;
    --install-1p-agent-config) INSTALL_1P_AGENT_CONFIG=1 ;;
    --github-add-key) GITHUB_ADD_KEY=1 ;;
    --github-key)
      GITHUB_KEY=1
      GITHUB_KEY_PATH="${2:-$HOME/.ssh/id_github}"
      shift
      ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown flag: $1" >&2; print_usage; exit 2 ;;
  esac
  shift
done

# Locate repo & inventory.yml
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
[[ -f "$INVENTORY" ]] || { echo "Inventory not found at $INVENTORY" >&2; exit 1; }

# Need yq
command -v yq >/dev/null 2>&1 || { echo "This script needs 'yq'. brew install yq" >&2; exit 1; }

# Prepare ~/.ssh layout
mkdir -p "$SSH_DIR/config.d" "$CONTROL_DIR"
chmod 700 "$SSH_DIR" "$SSH_DIR/config.d" "$CONTROL_DIR"

BASE_CFG="$SSH_DIR/config"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# helper: write file if content changed (backs up existing)
write_if_changed() {
  local path="$1"; shift
  local content="$*"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $path ----"
    printf "%s\n" "$content"
    return 0
  fi
  if [[ -f "$path" ]]; then
    if diff -q <(printf "%s\n" "$content") "$path" >/dev/null 2>&1; then
      return 0
    fi
    cp "$path" "$path.bak.$TIMESTAMP" || true
  fi
  printf "%s\n" "$content" > "$path"
  chmod 600 "$path"
}

# Base config
BASE_STANDARD="$(cat <<STD
# Managed by helix ssh_config_local.sh

Host *
  # Quality of life
  LogLevel QUIET
  AddKeysToAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes

  # Connection multiplexing (faster repeated SSH/scp)
  ControlMaster auto
  ControlPersist $CONTROL_PERSIST
  ControlPath $CONTROL_DIR/%r@%h:%p

  # Host key handling (use ask for strict checking; or accept-new if you trust LAN)
  StrictHostKeyChecking ask
  UserKnownHostsFile ~/.ssh/known_hosts

  # If you use 1Password SSH agent, uncomment:
  # IdentityAgent ~/.1password/agent.sock

# Pull in all host snippets
Include ~/.ssh/config.d/*.conf
STD
)"

if [[ $USE_1PASSWORD -eq 1 ]]; then
  BASE_CONTENT="$(printf "%s\n" "$BASE_STANDARD" \
    | sed 's/^  # IdentityAgent \(~\/\.1password\/agent\.sock\)$/  IdentityAgent \1/')"
else
  BASE_CONTENT="$BASE_STANDARD"
fi
write_if_changed "$BASE_CFG" "$BASE_CONTENT"

# macOS-only: NVIM_BG
if [[ "$(uname -s)" == "Darwin" ]]; then
  SENDENV_SNIPPET="$SSH_DIR/config.d/90-nvim-bg.conf"
  SENDENV_CONTENT="$(cat <<'SNIP'
# Managed by helix ssh_config_local.sh
# Send the Neovim light/dark hint to servers (NVIM_BG=light|dark)
Host *
  SendEnv NVIM_BG
SNIP
)"
  write_if_changed "$SENDENV_SNIPPET" "$SENDENV_CONTENT"
fi

# 1Password agent config (macOS)
if [[ $INSTALL_1P_AGENT_CONFIG -eq 1 && "$(uname -s)" == "Darwin" ]]; then
  src_base=""
  for p in "$HOME/.config/1Password/ssh/agent.toml" "$HOME/.config/1password/ssh/agent.toml"; do
    [[ -f "$p" ]] && src_base="$p" && break
  done
  if [[ -n "$src_base" ]]; then
    dst="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t"
    dst_file="$dst/agent.toml"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "---- would install $src_base -> $dst_file ----"
    else
      mkdir -p "$dst"
      if [[ ! -f "$dst_file" ]]; then
        cp -f "$src_base" "$dst_file"; chmod 600 "$dst_file"
        echo "==> Installed 1Password agent.toml to $dst"
        echo "    Tip: restart 1Password completely to reload."
      elif cmp -s "$src_base" "$dst_file"; then
        echo "✔ 1Password agent.toml already up to date"
      elif [[ $FORCE_1P_AGENT_CONFIG -eq 1 ]]; then
        cp -f "$src_base" "$dst_file"; chmod 600 "$dst_file"
        echo "↻ 1Password agent.toml replaced (forced)"
        echo "   Tip: restart 1Password completely to reload."
      else
        echo "⚠ 1Password agent.toml exists and differs; leaving as-is."
        echo "   Pass --force-1p-agent-config to overwrite."
      fi
    fi
  else
    echo "⚠ 1Password agent.toml not found under ~/.config/{1Password,1password}/ssh/"
  fi
fi

# GitHub via 1Password agent
if [[ $GITHUB_1PASSWORD -eq 1 ]]; then
  short_sock="$HOME/.1password/agent.sock"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    long_sock_mac="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "---- would ln -sfn '$long_sock_mac' -> '$short_sock' ----"
    else
      mkdir -p "$(dirname "$short_sock")"
      ln -sfn "$long_sock_mac" "$short_sock"
    fi
  fi

  GITHUB_SNIP="$SSH_DIR/config.d/10-github.conf"
  GITHUB_CONTENT="$(cat <<'SNIP'
# Managed by helix ssh_config_local.sh
# GitHub: prefer a local 1Password agent *if present*; otherwise use SSH_AUTH_SOCK
# (e.g., agent forwarding from a macOS client).

Host github.com
  HostName github.com
  User git

# Only set IdentityAgent when the local 1Password socket exists.
# If absent (e.g., headless server without 1Password), keep it unset so
# the default SSH_AUTH_SOCK (agent forwarding) is used instead.
Match host github.com exec "test -S $HOME/.1password/agent.sock"
  IdentityAgent ~/.1password/agent.sock
Match all
SNIP
)"
  write_if_changed "$GITHUB_SNIP" "$GITHUB_CONTENT"
fi

# Classic GitHub host using a dedicated key (Linux, no 1Password agent)
if [[ $GITHUB_KEY -eq 1 ]]; then
  GITHUB_CLASSIC_SNIP="$SSH_DIR/config.d/10-github-classic.conf"
  GITHUB_CLASSIC_CONTENT="$(cat <<SNIP
# Managed by helix ssh_config_local.sh
# GitHub (classic key)
Host github.com
  HostName github.com
  User git
  IdentityFile ${GITHUB_KEY_PATH}
  IdentitiesOnly yes
SNIP
)"
  write_if_changed "$GITHUB_CLASSIC_SNIP" "$GITHUB_CLASSIC_CONTENT"
fi

# -----------------------------
# Host filters (bash 3.2 friendly)
# -----------------------------
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
ONLY_LIST_NORM=""
if [[ -n "$ONLY_LIST" ]]; then
  # normalize to space-separated, lowercase, wrapped with spaces for safe matching
  ONLY_LIST_NORM=" $(printf '%s' "$ONLY_LIST" | tr '[:upper:]' '[:lower:]' | tr ',' ' ' | xargs) "
fi

# -----------------------------
# Parse inventory -> rows of: group \t host \t ansible_host \t ansible_user \t identity_file
# -----------------------------
YQ_QUERY='
  .all.children
  | to_entries[]
  | .key as $top_group
  | .value
  | ..
  | select(has("hosts"))
  | .hosts
  | to_entries[]
  | [
      $top_group,
      .key,
      (.value.ansible_host // ""),
      (.value.ansible_user // ""),
      (.value.identity_file // .value.ansible_ssh_private_key_file // "")
    ]
  | @tsv
'

# Iterate and create per-host snippets
while IFS=$'\t' read -r group host ans_host ans_user ans_identity; do
  [[ -z "${host:-}" ]] && continue

  # skip macOS unless explicitly requested
  if [[ "$group" == "macos" && $INCLUDE_MACOS -ne 1 ]]; then
    continue
  fi

  # --only filter
  if [[ -n "$ONLY_LIST_NORM" ]]; then
    case "$ONLY_LIST_NORM" in
      *" $(lc "$host") "*) : ;;   # keep
      *) continue ;;
    esac
  fi

  host_name="$ans_host"
  if [[ -z "$host_name" ]]; then
    if [[ -n "$DEFAULT_DOMAIN" ]]; then
      host_name="${host}.${DEFAULT_DOMAIN}"
    else
      host_name="$host"
    fi
  fi

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
  if [[ $FORWARD_AGENT_ALL -eq 1 ]]; then
    CONTENT+="  ForwardAgent yes\n"
  fi

  # Default: preserve existing per-host snippet
  if [[ -f "$CONF_PATH" && $REFRESH -eq 0 ]]; then
    [[ $DRY_RUN -eq 1 ]] && echo "---- would SKIP (exists) $CONF_PATH ----"
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $CONF_PATH ----"
    printf "%b" "$CONTENT"
  else
    printf "%b" "$CONTENT" > "$CONF_PATH"
    chmod 600 "$CONF_PATH"
  fi

done < <(yq -r "$YQ_QUERY" "$INVENTORY")

# Add 1Password public key to GitHub (idempotent)
if [[ $GITHUB_ADD_KEY -eq 1 ]]; then
  if command -v gh >/dev/null 2>&1 && command -v op >/dev/null 2>&1; then
    if ! gh auth status >/dev/null 2>&1; then
      echo "⚠ Skipping --github-add-key (gh is not authenticated). Run: gh auth login"
    else
      pub="$(op read 'op://security/GitHub/public key' || true)"
      if [[ -n "${pub:-}" ]]; then
        # Check if key already exists
        if gh api user/keys --jq '.[].key' 2>/dev/null | grep -Fqx "$pub"; then
          echo "✔ GitHub already has this 1Password public key"
        else
          if [[ $DRY_RUN -eq 1 ]]; then
            echo "---- would add GitHub public key from 1Password ----"
          else
            printf "%s\n" "$pub" | gh ssh-key add -t "1Password SSH (shared)" -
            echo "==> Added public key to GitHub"
          fi
        fi
      else
        echo "⚠ Could not read 'op://security/GitHub/public key'"
      fi
    fi
  else
    echo "⚠ Skipping --github-add-key (gh and/or op not found)"
  fi
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete. No files changed."
else
  echo "SSH config generated:"
  echo "   - Base: $BASE_CFG"
  echo "   - Snippets: $SSH_DIR/config.d/*.conf"
  [[ $GITHUB_1PASSWORD -eq 1 ]] && echo "   - GitHub via 1Password: $SSH_DIR/config.d/10-github.conf"
  echo "Tip: test with 'ssh -Tv git@github.com' and/or 'ssh -v nimbus'."
fi
