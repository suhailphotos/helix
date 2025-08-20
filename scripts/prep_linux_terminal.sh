#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# prep_linux_terminal.sh (v2)
# Make a Linux host friendly for Ghostty xterm-ghostty, install starship/eza,
# optionally purge p10k files, and copy your dotfiles from $MATRIX.
#
# RUN THIS ON THE LINUX HOST (flicker/nexus/etc).
# For Ghostty terminfo, run the provided one-liner ON YOUR MAC.
# -------------------------------------------------------------

log()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }
die()  { err "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --------- Defaults (override with flags/env) ----------
MATRIX_DEFAULT="$HOME/Dropbox/matrix"
MATRIX="${MATRIX:-$MATRIX_DEFAULT}"

COPY_CONFIGS=0
PURGE_P10K=0
INSTALL_STARSHIP=1
INSTALL_EZA=1
ADD_FALLBACKS=0
ALIAS_FALLBACK=0

# Allow overriding MATRIX root
usage() {
  cat <<'EOF'
Usage: prep_linux_terminal.sh [options]

Options:
  --matrix PATH           Path to your "matrix" root (default: $HOME/Dropbox/matrix or $MATRIX)
  --no-starship           Skip installing starship
  --no-eza                Skip installing eza
  --copy-configs          Copy configs:
                            $MATRIX/helix/dotfiles/zsh/.zshrc                 -> ~/.zshrc
                            $MATRIX/helix/dotfiles/eza/theme.yml              -> ~/.config/eza/theme.yml
                            $MATRIX/helix/dotfiles/starship/starship_linux_current.toml -> ~/.config/starship/starship.toml
  --purge-p10k            Remove Powerlevel10k files (no .zshrc edits)
  --add-fallbacks         Add TERM fallback snippet to ~/.bashrc and ~/.zshrc
  --alias-fallback        Install minimal xterm-ghostty alias to xterm-256color if terminfo is missing
  -h, --help              Show this help

Notes:
- Run this ON THE LINUX HOST.
- For Ghostty terminfo (xterm-ghostty), you'll get a one-liner to run ON YOUR MAC to copy the entry.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --matrix) MATRIX="$2"; shift 2;;
    --no-starship) INSTALL_STARSHIP=0; shift;;
    --no-eza) INSTALL_EZA=0; shift;;
    --copy-configs) COPY_CONFIGS=1; shift;;
    --purge-p10k) PURGE_P10K=1; shift;;
    --add-fallbacks) ADD_FALLBACKS=1; shift;;
    --alias-fallback) ALIAS_FALLBACK=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

# ---------------- Package Manager ----------------
PKG_MGR=""; PKG_INSTALL=""
detect_pkg_mgr() {
  if have apt-get; then PKG_MGR="apt"; PKG_INSTALL="sudo apt-get install -y"
  elif have dnf; then   PKG_MGR="dnf"; PKG_INSTALL="sudo dnf install -y"
  elif have yum; then   PKG_MGR="yum"; PKG_INSTALL="sudo yum install -y"
  elif have zypper; then PKG_MGR="zypper"; PKG_INSTALL="sudo zypper --non-interactive install"
  elif have pacman; then PKG_MGR="pacman"; PKG_INSTALL="sudo pacman -S --noconfirm"
  elif have apk; then    PKG_MGR="apk"; PKG_INSTALL="sudo apk add --no-cache"
  else die "No supported package manager found (apt/dnf/yum/zypper/pacman/apk)."; fi
  log "Package manager: $PKG_MGR"
}
pkg_update() {
  case "$PKG_MGR" in
    apt)    sudo apt-get update -y ;;
    dnf)    sudo dnf -y makecache || true ;;
    yum)    sudo yum makecache || true ;;
    zypper) sudo zypper refresh ;;
    pacman) sudo pacman -Sy --noconfirm ;;
    apk)    true ;;
  esac
}
install_pkgs() {
  local pkgs=("$@")
  case "$PKG_MGR" in
    apt|dnf|yum|zypper) $PKG_INSTALL "${pkgs[@]}" ;;
    pacman)             $PKG_INSTALL "${pkgs[@]}" ;;
    apk)                $PKG_INSTALL "${pkgs[@]}" ;;
  esac
}

ensure_basics() {
  pkg_update
  case "$PKG_MGR" in
    # Debian/Ubuntu
    apt)    install_pkgs ca-certificates curl git ncurses-bin ncurses-base ;;
    # Fedora/RHEL/openSUSE
    dnf|yum|zypper) install_pkgs ca-certificates curl git ncurses || true ;;
    # Arch
    pacman) install_pkgs ca-certificates curl git ncurses ;;
    # Alpine
    apk)    install_pkgs ca-certificates curl git ncurses ncurses-terminfo ;;
  esac
}

# ---------------- Installs ----------------
install_starship() {
  [[ $INSTALL_STARSHIP -eq 1 ]] || return 0
  log "Installing starship"
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
  if ! have starship; then warn "starship not on PATH; ensure ~/.local/bin is in PATH."; fi
}

install_eza() {
  [[ $INSTALL_EZA -eq 1 ]] || return 0
  log "Installing eza"
  if ! $PKG_INSTALL eza >/dev/null 2>&1; then
    warn "Package eza not available via $PKG_MGR. Install manually or via cargo (requires Rust): cargo install eza"
  fi
}

# ---------------- Optional Powerlevel10k purge ----------------
purge_p10k() {
  [[ $PURGE_P10K -eq 1 ]] || return 0
  log "Purging Powerlevel10k files (no .zshrc edits)"
  # Common locations
  rm -f "$HOME/.p10k.zsh" || true
  rm -rf "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || true
  rm -rf "/usr/share/powerlevel10k" 2>/dev/null || true
  rm -rf "/usr/local/share/powerlevel10k" 2>/dev/null || true
  rm -rf "/opt/homebrew/share/powerlevel10k" 2>/dev/null || true
}

# ---------------- Config copy ----------------
copy_configs() {
  [[ $COPY_CONFIGS -eq 1 ]] || return 0
  log "Copying config files from MATRIX: $MATRIX"

  local SRC_ZSHRC="$MATRIX/helix/dotfiles/zsh/.zshrc"
  local SRC_EZA="$MATRIX/helix/dotfiles/eza/theme.yml"
  local SRC_STAR="$MATRIX/helix/dotfiles/starship/starship_linux_current.toml"

  # .zshrc
  if [[ -f "$SRC_ZSHRC" ]]; then
    cp -f "$SRC_ZSHRC" "$HOME/.zshrc"
    log "Wrote ~/.zshrc"
  else
    warn "Missing: $SRC_ZSHRC"
  fi

  # eza theme
  if [[ -f "$SRC_EZA" ]]; then
    mkdir -p "$HOME/.config/eza"
    cp -f "$SRC_EZA" "$HOME/.config/eza/theme.yml"
    log "Wrote ~/.config/eza/theme.yml"
  else
    warn "Missing: $SRC_EZA"
  fi

  # starship config
  if [[ -f "$SRC_STAR" ]]; then
    mkdir -p "$HOME/.config/starship"
    cp -f "$SRC_STAR" "$HOME/.config/starship/starship.toml"
    log "Wrote ~/.config/starship/starship.toml"
  else
    warn "Missing: $SRC_STAR"
  fi
}

# ---------------- Ghostty terminfo ----------------
have_xterm_ghostty() { infocmp -x xterm-ghostty >/dev/null 2>&1; }

install_alias_fallback_terminfo() {
  log "Installing minimal alias terminfo for xterm-ghostty -> xterm-256color"
  tic -x - <<'EOF'
xterm-ghostty|Ghostty (compat via xterm-256color),
        use=xterm-256color,
EOF
}

print_mac_instructions() {
  cat <<'MAC'
To install the full Ghostty terminfo from your macOS host, run this ON YOUR MAC:

  # If Apple's ncurses is too old:
  #   brew install ncurses
  # Then use Homebrew's infocmp path:
  /opt/homebrew/opt/ncurses/bin/infocmp -x xterm-ghostty | ssh <user>@<server> -- tic -x -

  # Or try Apple's infocmp first:
  # infocmp -x xterm-ghostty | ssh <user>@<server> -- tic -x -
MAC
}

add_term_fallbacks() {
  [[ $ADD_FALLBACKS -eq 1 ]] || return 0
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

verify() {
  echo
  log "Verification"
  echo "MATRIX: ${MATRIX}"
  echo "Default SHELL: ${SHELL:-unknown}"
  echo "starship: $(command -v starship || echo 'not found')"
  echo "eza:      $(command -v eza || echo 'not found')"
  if have_xterm_ghostty; then
    echo "xterm-ghostty terminfo: PRESENT"
  else
    echo "xterm-ghostty terminfo: MISSING"
  fi
}

main() {
  detect_pkg_mgr
  ensure_basics

  # Installs
  install_starship
  install_eza

  # Optional cleanup & copies
  purge_p10k
  copy_configs

  # Terminfo
  if have_xterm_ghostty; then
    log "xterm-ghostty terminfo already present"
  else
    warn "xterm-ghostty terminfo is missing on this host."
    if [[ $ALIAS_FALLBACK -eq 1 ]]; then
      install_alias_fallback_terminfo || true
      if have_xterm_ghostty; then
        log "Installed minimal alias entry (features limited). Overwrite later with the full entry."
      else
        warn "Failed to install alias terminfo; is 'tic' available?"
      fi
    fi
    print_mac_instructions
  fi

  add_term_fallbacks
  verify
  log "Done. Open a new SSH session to test."
}

main "$@"
