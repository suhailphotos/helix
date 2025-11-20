#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
exec </dev/null

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

# 1Password item path. Adjust vault/name if you change it later.
# This assumes:
#   Vault:  security
#   Item:   proxmox-SSH-key
#   Field:  private key
PROXMOX_ITEM="${PROXMOX_ITEM:-op://security/proxmox-SSH-key/private key}"

# Where to write the key on disk
PROXMOX_KEY_PATH="${PROXMOX_KEY_PATH:-$SSH_DIR/id_proxmox}"

# --------- sanity checks ---------
if ! command -v op >/dev/null 2>&1; then
  echo "❌ 1Password CLI 'op' not found. Install it and sign in (op signin) first." >&2
  exit 1
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "❌ ssh-keygen not found. Install OpenSSH client tools." >&2
  exit 1
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Backup any existing id_proxmox
if [[ -f "$PROXMOX_KEY_PATH" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  mv "$PROXMOX_KEY_PATH" "$PROXMOX_KEY_PATH.bak.$ts"
  echo "ℹ️  Existing $PROXMOX_KEY_PATH backed up to $PROXMOX_KEY_PATH.bak.$ts"
fi

# 1) Pull OpenSSH-formatted private key from 1Password
#    This handles the 'not BEGIN OPENSSH PRIVATE KEY' issue.
umask 077
op read "${PROXMOX_ITEM}?ssh-format=openssh" > "$PROXMOX_KEY_PATH"
chmod 600 "$PROXMOX_KEY_PATH"

# 2) Regenerate public key from the private key
ssh-keygen -y -f "$PROXMOX_KEY_PATH" > "${PROXMOX_KEY_PATH}.pub"
chmod 644 "${PROXMOX_KEY_PATH}.pub"

echo "✅ Installed Proxmox SSH client key:"
echo "   Private: $PROXMOX_KEY_PATH"
echo "   Public : ${PROXMOX_KEY_PATH}.pub"
echo
echo "You can now point your SSH config / Ansible inventory at ~/.ssh/id_proxmox."
