#!/usr/bin/env bash
set -euo pipefail

# 0) Make targets
mkdir -p dotfiles/config/.config
mkdir -p dotfiles/home
mkdir -p dotfiles/config/.config/{eza,ghostty,starship}

# 1) XDG configs -> dotfiles/config/.config
git mv dotfiles/bat/.config/bat         dotfiles/config/.config/          || true
git mv dotfiles/btop/.config/btop       dotfiles/config/.config/          || true
git mv dotfiles/fzf/.config/fzf         dotfiles/config/.config/          || true
git mv dotfiles/git/.config/git         dotfiles/config/.config/          || true
git mv dotfiles/mc/.config/mc           dotfiles/config/.config/          || true
git mv dotfiles/npm/.config/npm         dotfiles/config/.config/          || true
git mv dotfiles/pip/.config/pip         dotfiles/config/.config/          || true
git mv dotfiles/ripgrep/.config/ripgrep dotfiles/config/.config/          || true
git mv dotfiles/tealdeer/.config/tealdeer dotfiles/config/.config/        || true
git mv dotfiles/wget/.config/wget       dotfiles/config/.config/          || true
git mv dotfiles/zoxide/.config/zoxide   dotfiles/config/.config/          || true

# curl: single file defaults to ~/.config/curlrc
[ -f dotfiles/curl/.config/curlrc ] && git mv dotfiles/curl/.config/curlrc dotfiles/config/.config/curlrc || true

# eza theme -> ~/.config/eza/theme.yml
[ -f dotfiles/eza/theme.yml ] && git mv dotfiles/eza/theme.yml dotfiles/config/.config/eza/theme.yml || true

# ghostty -> ~/.config/ghostty/{config,themes}
if [ -d dotfiles/ghostty ]; then
  [ -d dotfiles/ghostty/config ] && git mv dotfiles/ghostty/config dotfiles/config/.config/ghostty/config || true
  [ -d dotfiles/ghostty/themes ] && git mv dotfiles/ghostty/themes dotfiles/config/.config/ghostty/themes || true
fi

# nvim -> ~/.config/nvim
if [ -d dotfiles/nvim/.config/nvim ]; then
  git mv dotfiles/nvim/.config/nvim dotfiles/config/.config/nvim || true
fi

# starship: keep everything under ~/.config/starship/
# (we’ll point STARSHIP_CONFIG to starship/starship.toml in zsh)
if [ -d dotfiles/starship ]; then
  git mv dotfiles/starship/*.toml dotfiles/config/.config/starship/ 2>/dev/null || true
  [ -f dotfiles/starship/smart_path.zsh ] && git mv dotfiles/starship/smart_path.zsh dotfiles/config/.config/starship/smart_path.zsh || true
fi

# 2) Home-rooted files -> dotfiles/home
[ -f dotfiles/p10k/.p10k.zsh ] && git mv dotfiles/p10k/.p10k.zsh dotfiles/home/.p10k.zsh || true
[ -f dotfiles/tmux/.tmux.conf ] && git mv dotfiles/tmux/.tmux.conf dotfiles/home/.tmux.conf || true
[ -f dotfiles/zsh/.zshrc ] && git mv dotfiles/zsh/.zshrc dotfiles/home/.zshrc || true
[ -f dotfiles/gawk/.awkrc ] && git mv dotfiles/gawk/.awkrc dotfiles/home/.awkrc || true
if [ -d dotfiles/jq/.jq ]; then
  mkdir -p dotfiles/home
  git mv dotfiles/jq/.jq dotfiles/home/.jq || true
fi

# 3) Commit
git add -A
git commit -m "Restructure: consolidate configs to dotfiles/config/.config and home-rooted files to dotfiles/home"
