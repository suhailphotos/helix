#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
exec </dev/null

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
GITHUB_ITEM="${GITHUB_ITEM:-op://security/GitHub/private key}"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 1) Backup any existing id_github
if [[ -f "$SSH_DIR/id_github" ]]; then
  mv "$SSH_DIR/id_github" "$SSH_DIR/id_github.pkcs8.bak.$(date +%Y%m%d-%H%M%S)"
fi

# 2) Pull OpenSSH-formatted private key from 1Password
umask 077
op read "${GITHUB_ITEM}?ssh-format=openssh" > "$SSH_DIR/id_github"
chmod 600 "$SSH_DIR/id_github"

# 3) Regenerate public key from the private key
ssh-keygen -y -f "$SSH_DIR/id_github" > "$SSH_DIR/id_github.pub"
chmod 644 "$SSH_DIR/id_github.pub"

echo "✅ Installed GitHub SSH key at:"
echo "   $SSH_DIR/id_github"
echo "   $SSH_DIR/id_github.pub"
