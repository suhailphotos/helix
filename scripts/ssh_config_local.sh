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
USE_1PASSWORD=0                      # if 1 -> uncomment IdentityAgent in base; omit IdentityFile in snippets
INCLUDE_MACOS=0                      # if 1 -> include macOS group too
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-}" # e.g. "suhail.tech" to turn "nimbus" -> "nimbus.suhail.tech" if no ansible_host
DEFAULT_USER="${DEFAULT_USER:-$USER}"
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/id_rsa}"  # ignored when USE_1PASSWORD=1
DRY_RUN=0

# NEW: GitHub / 1Password helpers
GITHUB_1PASSWORD=0           # write GitHub-only snippet using 1Password agent
INSTALL_1P_AGENT_CONFIG=0    # copy agent.toml from ~/.config to 1Password sandbox
GITHUB_ADD_KEY=0             # add "op://security/GitHub/public key" to GitHub

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

  # NEW: GitHub via 1Password (symlink + snippet), install agent.toml, and add GitHub key
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

  # NEW (GitHub / 1Password)
  --github-1password            Create ~/.1password/agent.sock symlink (if needed) and write ~/.ssh/config.d/10-github.conf
  --install-1p-agent-config     Copy ~/.config/.../agent.toml to 1Password's sandbox path and chmod 600
  --github-add-key              Add "op://security/GitHub/public key" to your GitHub account (idempotent)

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

    # NEW flags
    --github-1password) GITHUB_1PASSWORD=1 ;;
    --install-1p-agent-config) INSTALL_1P_AGENT_CONFIG=1 ;;
    --github-add-key) GITHUB_ADD_KEY=1 ;;

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

# Base config
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
# macOS-only: always send NVIM_BG to servers
# -----------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  SENDENV_SNIPPET="$SSH_DIR/config.d/90-nvim-bg.conf"
  SENDENV_CONTENT="$(cat <<'SNIP'
# Managed by helix ssh_config_local.sh
# Send the Neovim light/dark hint to servers (NVIM_BG=light|dark)
Host *
  SendEnv NVIM_BG
SNIP
)"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $SENDENV_SNIPPET ----"
    printf "%s\n" "$SENDENV_CONTENT"
  else
    printf "%s\n" "$SENDENV_CONTENT" > "$SENDENV_SNIPPET"
    chmod 600 "$SENDENV_SNIPPET"
  fi
fi

# -----------------------------
# NEW: 1Password agent config install (macOS)
# -----------------------------
if [[ $INSTALL_1P_AGENT_CONFIG -eq 1 ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
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
          cp -f "$src_base" "$dst_file"
          chmod 600 "$dst_file"
          echo "==> Installed 1Password agent.toml to $dst"
          echo "    Tip: restart 1Password completely to reload."
        elif cmp -s "$src_base" "$dst_file"; then
          echo "✔ 1Password agent.toml already up to date"
        elif [[ $FORCE_1P_AGENT_CONFIG -eq 1 ]]; then
          cp -f "$src_base" "$dst_file"
          chmod 600 "$dst_file"
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
  else
    echo "ℹ Skipping --install-1p-agent-config (non-macOS)."
  fi
fi

# -----------------------------
# NEW: GitHub via 1Password agent (symlink on mac; conditional IdentityAgent everywhere)
# -----------------------------
if [[ $GITHUB_1PASSWORD -eq 1 ]]; then
  short_sock="$HOME/.1password/agent.sock"

  # macOS: ensure the canonical short path points at the long sandbox path
  if [[ "$(uname -s)" == "Darwin" ]]; then
    long_sock_mac="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "---- would ln -sfn '$long_sock_mac' -> '$short_sock' ----"
    else
      mkdir -p "${short_sock:h}"
      ln -sfn "$long_sock_mac" "$short_sock"
    fi
  fi

  GITHUB_SNIP="$SSH_DIR/config.d/10-github.conf"
  read -r -d '' GITHUB_CONTENT <<'SNIP'
# Managed by helix ssh_config_local.sh
# GitHub: prefer a local 1Password agent *if present*; otherwise use SSH_AUTH_SOCK
# (e.g., agent forwarding from a macOS client).

Host github.com
  HostName github.com
  User git
  IdentitiesOnly yes

# Only set IdentityAgent when the local 1Password socket exists.
# If absent (e.g., headless server without 1Password), we keep it unset so
# the default SSH_AUTH_SOCK (agent forwarding) is used instead.
Match host github.com exec "test -S $HOME/.1password/agent.sock"
  IdentityAgent ~/.1password/agent.sock
Match all
SNIP

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $GITHUB_SNIP ----"
    printf "%s\n" "$GITHUB_CONTENT"
  else
    printf "%s\n" "$GITHUB_CONTENT" > "$GITHUB_SNIP"
    chmod 600 "$GITHUB_SNIP"
  fi
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
  if [[ "$group" == "macos" && $INCLUDE_MACOS -ne 1 ]]; then
    continue
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

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "---- would write $CONF_PATH ----"
    printf "%b" "$CONTENT"
  else
    printf "%b" "$CONTENT" > "$CONF_PATH"
    chmod 600 "$CONF_PATH"
  fi

done < <(yq -r "$YQ_QUERY" "$INVENTORY")

# -----------------------------
# NEW: Add 1Password public key to GitHub (idempotent)
# -----------------------------
if [[ $GITHUB_ADD_KEY -eq 1 ]]; then
  if command -v gh >/dev/null 2>&1 && command -v op >/dev/null 2>&1; then
    pub="$(op read 'op://security/GitHub/public key' || true)"
    if [[ -n "${pub:-}" ]]; then
      set +e
      gh api user/keys --jq '.[].key' 2>/dev/null | grep -Fqx "$pub"
      already=$?
      set -e
      if [[ $already -ne 0 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          echo "---- would add GitHub public key from 1Password ----"
        else
          printf "%s\n" "$pub" | gh ssh-key add -t "1Password SSH (shared)" -
          echo "==> Added public key to GitHub"
        fi
      else
        echo "✔ GitHub already has this 1Password public key"
      fi
    else
      echo "⚠ Could not read 'op://security/GitHub/public key'"
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
