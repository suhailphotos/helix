#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# bootstrap_nimbus.sh  (Ubuntu/Debian)
# One-time prepare script to make zsh + starship + eza + terminfo(ghostty)
# work nicely when SSH-ing from macOS (Ghostty).
#
# Run this first, then run your existing NVIM migrate script.
# -------------------------------------------------------------

log()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

detect_distro() {
  if [ ! -f /etc/os-release ]; then die "Unsupported OS: /etc/os-release not found"; fi
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) die "This script targets Ubuntu/Debian. Detected: ${ID:-unknown}";;
  esac
  echo "${ID}"
}

ensure_apt_basics() {
  log "Updating apt and installing base tools"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip tar gzip file \
    pkg-config build-essential locales
  # Ensure common locale present (avoids some ncurses/UTF-8 issues)
  if ! locale -a | grep -qi 'en_US.utf8'; then
    sudo locale-gen en_US.UTF-8 || true
  fi
}

install_zsh_and_set_default() {
  log "Installing zsh"
  sudo apt-get install -y zsh
  local zsh_path
  zsh_path="$(command -v zsh)"
  if ! grep -q "$zsh_path" /etc/shells; then
    log "Adding $zsh_path to /etc/shells"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "${SHELL:-}" != "$zsh_path" ]; then
    log "Changing default shell to zsh for $USER"
    chsh -s "$zsh_path" || warn "chsh failed (non-interactive?). You can run: chsh -s \"$zsh_path\""
  else
    log "zsh already set as default shell"
  fi
}

install_starship() {
  log "Installing starship"
  # Prefer apt if available (Ubuntu 24.04+ has starship)
  if sudo apt-get install -y starship >/dev/null 2>&1; then
    log "Installed starship via apt"
  else
    warn "apt starship not available, using official installer to ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
  fi
  command -v starship >/dev/null 2>&1 || die "starship not found after install"
}

install_eza() {
  log "Installing eza"
  if sudo apt-get install -y eza >/dev/null 2>&1; then
    log "Installed eza via apt"
  else
    warn "apt eza not available. Installing via cargo (will install rustup if needed)."
    if ! command -v rustup >/dev/null 2>&1; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi
    # Source cargo env for this session
    if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
    cargo install eza
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.cargo/bin/eza" "$HOME/.local/bin/eza"
  fi
  command -v eza >/dev/null 2>&1 || die "eza not found after install"
}

install_ghostty_terminfo() {
  log "Installing Ghostty terminfo"
  # This teaches ncurses about the 'ghostty' terminal type
  curl -fsSL https://raw.githubusercontent.com/mitchellh/ghostty/main/misc/terminfo | tic -x -
  infocmp ghostty >/dev/null 2>&1 && log "ghostty terminfo present" || warn "ghostty terminfo missing"
}

ensure_path_and_shell_rcs() {
  log "Configuring shell startup files"

  # Ensure ~/.local/bin is on PATH for both bash and zsh
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
    printf '\n# user bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
  fi

  # Bash: TERM fallback if unknown (so 'clear' etc. work even with odd TERM)
  if ! grep -q 'infocmp "\$TERM"' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'BASHRC_FALLBACK'

# --- terminfo fallback for unknown terminals ---
if ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
BASHRC_FALLBACK
  fi

  # Zsh: initialize starship and include same TERM fallback
  mkdir -p "$HOME"
  touch "$HOME/.zshrc"
  if ! grep -q 'eval "\$\(starship init zsh\)"' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'ZSHRC_BLOCK'

# --- PATH for user bin ---
export PATH="$HOME/.local/bin:$PATH"

# --- terminfo fallback for unknown terminals ---
if ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# --- starship prompt ---
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
ZSHRC_BLOCK
  fi
}

verify() {
  echo
  log "Verifying installs"
  echo "SHELL: $SHELL"
  command -v zsh   && zsh --version   || true
  command -v starship && starship -V  || true
  command -v eza   && eza --version   || true
  echo "TERM: ${TERM:-unset}"
  infocmp ghostty >/dev/null 2>&1 && echo "ghostty terminfo OK" || echo "ghostty terminfo not found"
}

main() {
  need_cmd curl
  detect_distro >/dev/null
  ensure_apt_basics
  install_zsh_and_set_default
  install_starship
  install_eza
  install_ghostty_terminfo
  ensure_path_and_shell_rcs
  verify
  echo
  log "Done."
  cat <<'NEXT'
Next steps:
  1) Log out and back in (or start a new SSH session) so your default shell becomes zsh.
  2) From your Mac, you should be able to:   ssh nimbus
     (No need for TERM=xterm-256color once ghostty terminfo is installed.)
  3) Then run your Neovim/tmux migrate script as usual.

Sanity checks on nimbus:
  echo $SHELL
  echo $TERM
  infocmp ghostty | head -n 1
  starship -V
  eza --version
NEXT
}

main "$@"
