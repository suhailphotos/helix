#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# prep_linux_terminal.sh
# Make a Linux host friendly for Ghostty (xterm-ghostty), zsh, and optional tools.
#
# Defaults: only ensure zsh installed/activated and verify terminfo presence.
# Optional flags to install starship/eza, add TERM fallbacks, or set alias fallback terminfo.
# -------------------------------------------------------------

log()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

PKG_MGR=""
PKG_INSTALL=""
detect_pkg_mgr() {
  if have_cmd apt-get; then
    PKG_MGR="apt"
    PKG_INSTALL="sudo apt-get install -y"
  elif have_cmd dnf; then
    PKG_MGR="dnf"
    PKG_INSTALL="sudo dnf install -y"
  elif have_cmd yum; then
    PKG_MGR="yum"
    PKG_INSTALL="sudo yum install -y"
  elif have_cmd zypper; then
    PKG_MGR="zypper"
    PKG_INSTALL="sudo zypper --non-interactive install"
  elif have_cmd pacman; then
    PKG_MGR="pacman"
    PKG_INSTALL="sudo pacman -S --noconfirm"
  elif have_cmd apk; then
    PKG_MGR="apk"
    PKG_INSTALL="sudo apk add --no-cache"
  else
    die "Unsupported distro: no known package manager found (apt/dnf/yum/zypper/pacman/apk)."
  fi
  log "Package manager: $PKG_MGR"
}

pkg_update() {
  case "$PKG_MGR" in
    apt)    sudo apt-get update -y ;;
    dnf)    sudo dnf -y makecache || true ;;
    yum)    sudo yum makecache || true ;;
    zypper) sudo zypper refresh ;;
    pacman) sudo pacman -Sy --noconfirm ;;
    apk)    true ;; # no global update needed
  esac
}

install_pkgs() {
  local pkgs=("$@")
  case "$PKG_MGR" in
    apt)
      $PKG_INSTALL "${pkgs[@]}"
      ;;
    dnf|yum)
      $PKG_INSTALL "${pkgs[@]}"
      ;;
    zypper)
      $PKG_INSTALL "${pkgs[@]}"
      ;;
    pacman)
      # translate some package names for Arch if needed
      local translated=()
      for p in "${pkgs[@]}"; do
        case "$p" in
          eza) translated+=(eza) ;;
          zsh) translated+=(zsh) ;;
          ncurses) translated+=(ncurses) ;;
          terminfo) translated+=(ncurses) ;; # terminfo is part of ncurses on Arch
          curl) translated+=(curl) ;;
          ca-certificates) translated+=(ca-certificates) ;;
          git) translated+=(git) ;;
          *) translated+=("$p") ;;
        esac
      done
      $PKG_INSTALL "${translated[@]}"
      ;;
    apk)
      # Alpine package names
      local translated=()
      for p in "${pkgs[@]}"; do
        case "$p" in
          eza) translated+=(eza) ;;
          zsh) translated+=(zsh) ;;
          ncurses|terminfo) translated+=(ncurses-terminfo) ;;
          curl) translated+=(curl) ;;
          ca-certificates) translated+=(ca-certificates) ;;
          git) translated+=(git) ;;
          *) translated+=("$p") ;;
        esac
      done
      $PKG_INSTALL "${translated[@]}"
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: prep_linux_terminal.sh [options]

Options:
  --install-starship       Install Starship (no shell init; you manage .zshrc)
  --install-eza            Install eza
  --add-fallbacks          Add TERM fallback snippet to ~/.bashrc and ~/.zshrc
  --alias-fallback         If xterm-ghostty terminfo is missing, install a minimal alias
                           that uses xterm-256color capabilities (reduced features)
  --no-chsh                Do not change default shell (even if zsh is installed)
  -h, --help               Show this help

Notes:
  * This script ensures zsh is installed and makes it your default shell unless --no-chsh is used.
  * It verifies Ghostty's terminfo (xterm-ghostty). If missing, you'll get a one-liner to run from
    your Mac to copy the entry over. If you pass --alias-fallback, it installs a minimal alias instead.
  * It does NOT edit your ~/.zshrc unless you use --add-fallbacks (safe TERM fallback).
EOF
}

INSTALL_STARSHIP=0
INSTALL_EZA=0
ADD_FALLBACKS=0
ALIAS_FALLBACK=0
DO_CHSH=1

for arg in "$@"; do
  case "$arg" in
    --install-starship) INSTALL_STARSHIP=1 ;;
    --install-eza) INSTALL_EZA=1 ;;
    --add-fallbacks) ADD_FALLBACKS=1 ;;
    --alias-fallback) ALIAS_FALLBACK=1 ;;
    --no-chsh) DO_CHSH=0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

ensure_basics() {
  pkg_update
  case "$PKG_MGR" in
    apt)    install_pkgs ca-certificates curl git ncurses-bin ncurses-base ;;
    dnf|yum) install_pkgs ca-certificates curl git ncurses ;;
    zypper) install_pkgs ca-certificates curl git ncurses ;;
    pacman) install_pkgs ca-certificates curl git ncurses ;;
    apk)    install_pkgs ca-certificates curl git ncurses-terminfo ;;
  esac
}

ensure_zsh() {
  if ! have_cmd zsh; then
    log "Installing zsh"
    install_pkgs zsh
  else
    log "zsh already installed"
  fi

  if [ "$DO_CHSH" -eq 1 ]; then
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ "${SHELL:-}" != "$zsh_path" ]; then
      if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null || true
      fi
      log "Setting default shell to: $zsh_path"
      chsh -s "$zsh_path" || warn "chsh failed (non-interactive shell?). Re-run manually: chsh -s \"$zsh_path\""
    else
      log "zsh already the default shell"
    fi
  else
    log "--no-chsh specified; not changing default shell"
  fi
}

install_starship_if_requested() {
  [ "$INSTALL_STARSHIP" -eq 1 ] || return 0
  log "Installing starship (no shell init)"
  case "$PKG_MGR" in
    apt)
      if ! sudo apt-get install -y starship >/dev/null 2>&1; then
        warn "apt starship not available; using official installer to ~/.local/bin"
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
      fi
      ;;
    dnf|yum|zypper|pacman|apk)
      if ! $PKG_INSTALL starship >/dev/null 2>&1; then
        warn "Package starship not available; using official installer to ~/.local/bin"
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
      fi
      ;;
  esac
  command -v starship >/dev/null 2>&1 || warn "starship not found on PATH (installed to ~/.local/bin). Add it to PATH if needed."
}

install_eza_if_requested() {
  [ "$INSTALL_EZA" -eq 1 ] || return 0
  log "Installing eza"
  if ! $PKG_INSTALL eza >/dev/null 2>&1; then
    warn "Package eza not available via $PKG_MGR."
    warn "Install eza manually or via cargo:  cargo install eza  (requires Rust)"
  fi
}

have_xterm_ghostty() {
  infocmp -x xterm-ghostty >/dev/null 2>&1
}

install_alias_fallback_terminfo() {
  log "Installing minimal alias terminfo for xterm-ghostty -> xterm-256color"
  tic -x - <<'EOF'
xterm-ghostty|Ghostty (compat via xterm-256color),
        use=xterm-256color,
EOF
}

explain_copy_from_mac() {
  cat <<'MACINSTRUCT'

To install the full Ghostty terminfo from your macOS host, run this ON YOUR MAC:

  # If your macOS ncurses is too old, first:
  #   brew install ncurses
  #   and then use: /opt/homebrew/opt/ncurses/bin/infocmp

  infocmp -x xterm-ghostty | ssh <user>@<server> -- tic -x -

Notes:
  * This copies the complete xterm-ghostty entry from your Mac to the server.
  * If you see a tic warning about "older tic versions may treat the description
    field as an alias", you can safely ignore it.
MACINSTRUCT
}

add_term_fallbacks_if_requested() {
  [ "$ADD_FALLBACKS" -eq 1 ] || return 0
  log "Adding TERM fallback snippet to ~/.bashrc and ~/.zshrc"
  # bash
  touch "$HOME/.bashrc"
  if ! grep -q 'infocmp "\$TERM"' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'BASHRC_FALLBACK'

# --- terminfo fallback for unknown terminals ---
if ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
BASHRC_FALLBACK
  fi
  # zsh
  touch "$HOME/.zshrc"
  if ! grep -q 'infocmp "\$TERM"' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'ZSHRC_FALLBACK'

# --- terminfo fallback for unknown terminals ---
if ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
ZSHRC_FALLBACK
  fi
}

sudo_note() {
  cat <<'SUDONOTE'

sudo note:
  If sudo resets environment and you see "missing or unsuitable terminal: xterm-ghostty"
  under sudo, configure sudo to preserve TERMINFO or enable Ghostty's shell integration
  with: shell-integration-features = sudo
SUDONOTE
}

verify() {
  echo
  log "Verification"
  echo "Default SHELL: ${SHELL:-unknown}"
  if have_xterm_ghostty; then
    echo "xterm-ghostty terminfo: PRESENT"
  else
    echo "xterm-ghostty terminfo: MISSING"
  fi
  echo "TERM at runtime will be set by your terminal (Ghostty sets TERM=xterm-ghostty)."
}

main() {
  detect_pkg_mgr
  ensure_basics
  ensure_zsh

  install_starship_if_requested
  install_eza_if_requested

  if have_xterm_ghostty; then
    log "xterm-ghostty terminfo already present"
  else
    warn "xterm-ghostty terminfo is missing on this host."
    if [ "$ALIAS_FALLBACK" -eq 1 ]; then
      install_alias_fallback_terminfo
      if have_xterm_ghostty; then
        log "Installed minimal alias entry. Advanced Ghostty features may be limited."
      else
        warn "Failed to install alias terminfo; ensure tic is available and try again."
      fi
    fi
    explain_copy_from_mac
  fi

  add_term_fallbacks_if_requested
  sudo_note
  verify
  log "Done. Open a new SSH session to test."
}

main "$@"
