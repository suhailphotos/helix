#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# Suhail NVIM migrate v5.1 (Ubuntu/Debian)
# -------------------------------------------------------------
# What this script does:
#  - Remove packer artifacts
#  - Remove any user-local ~/.local/bin/nvim symlink (prevents PATH shadowing)
#  - Purge distro neovim + neovim-runtime to avoid .deb conflicts
#  - Install official Neovim v0.11.3 .deb from neovim/neovim-releases
#  - Install base deps: ripgrep, fd-find, clipboard utils, build tools, Python/pip
#  - Install Node.js (LTS) so mason can install typescript-language-server (ts_ls)
#  - Clean lazy-rocks cache (avoids LuaRocks/hererocks errors)
#  - Build tmux 3.5a to ~/.local (fallback to distro tmux)
#  - Optional flags to install Go and/or Rust toolchains for other Mason packages
#  - Optional: apt-mark hold neovim (--hold)
#
# Not doing:
#  - Does NOT copy your config. Run rsync separately after.
# -------------------------------------------------------------

NV_VER="${NV_VER:-v0.11.3}"
TMUX_VER="${TMUX_VER:-3.5a}"
NODE_MAJOR="${NODE_MAJOR:-22}"   # default to Node.js 22 LTS
INSTALL_GO=0
INSTALL_RUST=0
APT_HOLD=0

log()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

usage() {
  cat <<EOF
Usage: $0 [--hold] [--with-go] [--with-rust]

  --hold       apt-mark hold neovim after installing v${NV_VER#v}
  --with-go    also install Go toolchain (for servers like sqls, gopls)
  --with-rust  also install Rust toolchain via rustup (for servers/tools that need cargo)

Environment overrides:
  NV_VER=v0.11.3     # pin Neovim version from neovim-releases
  TMUX_VER=3.5a      # pin tmux release
  NODE_MAJOR=22      # Node.js major LTS version via NodeSource
EOF
}

detect_distro() {
  if [ ! -f /etc/os-release ]; then die "Unsupported OS: /etc/os-release not found"; fi
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) die "This script targets Ubuntu/Debian. Detected: ${ID:-unknown}";;
  esac
  echo "${ID}"
}

remove_packer_artifacts() {
  local pack_dir="${HOME}/.local/share/nvim/site/pack/packer"
  local compiled_lua="${HOME}/.config/nvim/plugin/packer_compiled.lua"
  if [ -d "$pack_dir" ]; then log "Removing packer dir: $pack_dir"; rm -rf "$pack_dir"; fi
  if [ -f "$compiled_lua" ]; then log "Removing packer compiled file: $compiled_lua"; rm -f "$compiled_lua"; fi
}

remove_user_local_nvim_symlink() {
  local ln="$HOME/.local/bin/nvim"
  if [ -L "$ln" ]; then log "Removing user-local nvim symlink: $ln"; rm -f "$ln"; fi
}

install_base_packages() {
  log "Installing base packages via apt"
  sudo apt-get update -y
  sudo apt-get install -y software-properties-common >/dev/null 2>&1 || true
  sudo apt-get install -y build-essential pkg-config git curl unzip tar gzip file ca-certificates \
                          ripgrep fd-find xclip wl-clipboard python3 python3-pip
  # fd convenience
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/bin"
    ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
    log "Symlinked: ~/.local/bin/fd -> $(command -v fdfind)"
  fi
}

purge_old_neovim() {
  log "Removing distro neovim packages (avoid .deb conflicts)"
  sudo apt remove -y neovim neovim-runtime || true
  sudo apt autoremove -y || true
}

arch_asset_deb() {
  local arch; arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "nvim-linux-x86_64.deb" ;;
    aarch64|arm64) echo "nvim-linux-arm64.deb" ;;
    *) die "Unsupported architecture for .deb: $arch" ;;
  esac
}

install_neovim_deb() {
  local asset url debfile
  asset="$(arch_asset_deb)"
  url="https://github.com/neovim/neovim-releases/releases/download/${NV_VER}/${asset}"
  debfile="/tmp/${asset}"

  log "Downloading Neovim ${NV_VER} (${asset})"
  curl -fL -o "${debfile}" "${url}" || die "Download failed: ${url}"

  log "Installing Neovim ${NV_VER}"
  sudo apt install -y "${debfile}" || die "Failed to install ${debfile}"
}

hold_neovim_if_requested() {
  if [ "${APT_HOLD}" = "1" ]; then
    log "Holding 'neovim' to prevent downgrades"
    sudo apt-mark hold neovim || warn "Failed to hold neovim (non-fatal)"
  fi
}

install_node_lts() {
  # Prefer NodeSource LTS for consistent npm availability for Mason
  log "Installing Node.js ${NODE_MAJOR} LTS via NodeSource"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh || {
    warn "NodeSource setup download failed; trying apt 'nodejs' (version may vary)"
    sudo apt-get install -y nodejs npm || warn "Fallback nodejs install failed"
    return
  }
  sudo -E bash /tmp/nodesource_setup.sh
  sudo apt-get install -y nodejs
  # Optional: corepack to enable yarn/pnpm if needed by other packages
  if command -v corepack >/dev/null 2>&1; then corepack enable || true; fi
  if ! command -v npm >/dev/null 2>&1; then warn "npm not found after Node install"; fi
  node -v || true
  npm -v || true
}

install_go_if_requested() {
  if [ "$INSTALL_GO" -eq 1 ]; then
    log "Installing Go toolchain (for Mason packages like sqls/gopls)"
    sudo apt-get install -y golang || warn "Failed to install golang"
    go version || true
  fi
}

install_rust_if_requested() {
  if [ "$INSTALL_RUST" -eq 1 ]; then
    log "Installing Rust toolchain via rustup (for cargo-based tools)"
    if ! command -v rustup >/dev/null 2>&1; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path || warn "rustup install failed"
    fi
    # Source cargo env for this session
    if [ -f "${HOME}/.cargo/env" ]; then . "${HOME}/.cargo/env"; fi
    rustup toolchain install stable || true
    rustup default stable || true
    rustc --version || true
    cargo --version || true
  fi
}

clean_lazy_rocks() {
  local rocks="${HOME}/.local/share/nvim/lazy-rocks"
  if [ -d "$rocks" ]; then
    log "Removing lazy-rocks cache: $rocks"
    rm -rf "$rocks"
  fi
}

build_tmux_35a() {
  log "Installing tmux build dependencies"
  sudo apt-get install -y libevent-dev libncurses-dev libncursesw5-dev bison

  local url="https://github.com/tmux/tmux/releases/download/${TMUX_VER}/tmux-${TMUX_VER}.tar.gz"
  local tmp; tmp="$(mktemp -d)"
  pushd "$tmp" >/dev/null

  log "Downloading tmux ${TMUX_VER}"
  curl -fL -o tmux.tar.gz "$url" || { warn "tmux download failed"; popd >/dev/null; rm -rf "$tmp"; return 1; }
  tar -xzf tmux.tar.gz
  cd "tmux-${TMUX_VER}"
  ./configure --prefix="${HOME}/.local" >/dev/null
  make -j"$(nproc || echo 2)" >/dev/null
  make install >/dev/null

  popd >/dev/null
  rm -rf "$tmp"
  log "tmux ${TMUX_VER} installed to ~/.local/bin/tmux"
  return 0
}

install_tmux_fallback() {
  warn "Falling back to distro tmux"
  sudo apt-get install -y tmux
}

ensure_local_bin_on_path() {
  if ! printf '%s' "$PATH" | grep -q "$HOME/.local/bin"; then
    log "Adding ~/.local/bin to PATH in ~/.profile"
    printf '\n# helix: user bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
  fi
}

verify_versions() {
  echo
  log "Verifying installs"
  nvim --version | head -n 2 || die "nvim not found on PATH"
  tmux -V || [ -x "${HOME}/.local/bin/tmux" ] && "${HOME}/.local/bin/tmux" -V || true
  node -v || warn "node not found"
  npm -v || warn "npm not found"
}

main() {
  # Parse flags
  for arg in "$@"; do
    case "$arg" in
      --hold) APT_HOLD=1 ;;
      --with-go) INSTALL_GO=1 ;;
      --with-rust) INSTALL_RUST=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown argument: $arg" ;;
    esac
  done

  need_cmd curl

  local distro; distro="$(detect_distro)"
  log "Distro: ${distro}"
  log "Target Neovim: ${NV_VER}, tmux: ${TMUX_VER}, Node LTS: ${NODE_MAJOR}.x"

  remove_packer_artifacts
  remove_user_local_nvim_symlink
  install_base_packages
  purge_old_neovim
  install_neovim_deb
  [ "$APT_HOLD" -eq 1 ] && { log "Holding neovim package"; sudo apt-mark hold neovim || true; }

  install_node_lts
  install_go_if_requested
  install_rust_if_requested

  clean_lazy_rocks

  if ! build_tmux_35a; then
    install_tmux_fallback
  fi
  ensure_local_bin_on_path
  verify_versions

  echo
  log "Done. Next:"
  cat <<'EOS'
  • rsync your config FROM mac → linux:
      rsync -av --delete ~/.config/nvim/ suhail@nimbus.suhail.tech:~/.config/nvim/

  • In lua/suhail/lazy_init.lua, disable rocks (no LuaRocks/hererocks):
      local rocks_enabled = (vim.env.LAZY_ROCKS == "1")
      require("lazy").setup({
        spec = "suhail.lazy",
        change_detection = { notify = false },
        install = { colorscheme = { "rose-pine", "tokyonight" } },
        rocks = { enabled = rocks_enabled, hererocks = false },
      })
    Or simply:
      rocks = { enabled = false, hererocks = false },

  • Inside Neovim:
      :MasonInstall typescript-language-server
      :Lazy
      :Mason
      :checkhealth
EOS
}

main "$@"

