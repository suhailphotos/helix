#!/usr/bin/env bash

set -euo pipefail

USER_HOME="${HOME}"

#--------------------#
#  Prerequisites     #
#--------------------#
install_prereqs() {
  echo "Requesting admin access for Homebrew installation if needed..."
  sudo -v

  echo "Checking for Xcode Command Line Tools..."
  if ! xcode-select -p &> /dev/null; then
    echo "Xcode Command Line Tools not found."
    echo "Please run: xcode-select --install"
    echo "After installation is complete, rerun this script."
    exit 1
  fi
  echo "Xcode Command Line Tools found."

  echo "Checking for Homebrew..."
  if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
    ZPROFILE="${HOME}/.zprofile"
    grep -qxF "$BREW_LINE" "$ZPROFILE" 2>/dev/null || echo "$BREW_LINE" >> "$ZPROFILE"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Homebrew is already installed."
  fi

  echo "Checking for Git..."
  if ! command -v git &> /dev/null; then
    echo "Git not found. Installing via Homebrew..."
    brew install git
  else
    echo "Git is already installed."
  fi
}

install_meslo_fonts() {
  echo "Installing MesloLGS NF fonts directly (recommended by Powerlevel10k)..."
  FONT_DIR="${USER_HOME}/Library/Fonts"
  mkdir -p "$FONT_DIR"

  # Download each style
  curl -fsSL -o "$FONT_DIR/MesloLGS NF Regular.ttf" \
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  curl -fsSL -o "$FONT_DIR/MesloLGS NF Bold.ttf" \
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
  curl -fsSL -o "$FONT_DIR/MesloLGS NF Italic.ttf" \
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
  curl -fsSL -o "$FONT_DIR/MesloLGS NF Bold Italic.ttf" \
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"

  echo "MesloLGS NF fonts installed. You may need to restart iTerm2 to see them."
}


#------------------------------#
#  Install font and iTerm2     #
#------------------------------#
install_iterm2_and_font() {
  echo "Installing MesloLGS Nerd Font..."
  install_meslo_fonts

  echo "Installing iTerm2 via Homebrew..."
  brew install --cask iterm2

  # Download iTerm2 profile and color scheme to Downloads for user import
  IT2_PROFILE_JSON_URL="https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/dotfiles/iterm/suhail_item2_profiles.json"
  IT2_PROFILE_JSON_PATH="${USER_HOME}/Downloads/suhail_item2_profiles.json"
  echo "Downloading iTerm2 profile JSON to ~/Downloads..."
  curl -fsSL "$IT2_PROFILE_JSON_URL" -o "$IT2_PROFILE_JSON_PATH"

  COLOR_FILE_URL="https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/dotfiles/iterm/suhailTerm2.itermcolors"
  COLOR_FILE_PATH="${USER_HOME}/Downloads/suhailTerm2.itermcolors"
  echo "Downloading iTerm2 color preset to ~/Downloads..."
  curl -fsSL "$COLOR_FILE_URL" -o "$COLOR_FILE_PATH"

  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "To finish setting up iTerm2:"
  echo
  echo "1. Open iTerm2."
  echo "2. Go to Preferences > Profiles > Other Actions (gear) > Import."
  echo "   Import:  ~/Downloads/suhail_item2_profiles.json"
  echo "3. Right-click your imported profile and choose Set as Default."
  echo
  echo "To import colors:"
  echo "4. Go to Preferences > Profiles > Colors."
  echo "5. Click Color Presets… > Import…"
  echo "   Import:  ~/Downloads/suhailTerm2.itermcolors"
  echo "6. With your profile selected, choose 'suhailTerm2' from the Color Presets list."
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
}

#------------------------------#
#  Patch .zshrc for Powerlevel10k
#------------------------------#
patch_zshrc_for_p10k() {
  local ZSHRC="${USER_HOME}/.zshrc"
  local INSTANT_BLOCK="# Enable Powerlevel10k instant prompt."
  local P10K_SOURCE='[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'
  local TMP=/tmp/zshrc_patched

  # 1. Add instant prompt block to very top if missing
  if ! grep -qF "$INSTANT_BLOCK" "$ZSHRC"; then
    cat <<'EOF' > "$TMP"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

EOF
    cat "$ZSHRC" >> "$TMP"
    mv "$TMP" "$ZSHRC"
  fi

  # 2. Ensure .p10k.zsh is sourced at the end
  if ! grep -qF "$P10K_SOURCE" "$ZSHRC"; then
    echo "$P10K_SOURCE" >> "$ZSHRC"
  fi
}

#--------------------#
#  Zsh + P10k setup  #
#--------------------#
install_zsh_and_p10k() {
  echo "Installing Oh My Zsh..."
  export RUNZSH=no  # Prevent Oh My Zsh installer from launching zsh interactively
  export CHSH=no    # Prevent changing shell during install
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  echo "Installing Powerlevel10k theme..."
  ZSH_CUSTOM="${ZSH_CUSTOM:-${USER_HOME}/.oh-my-zsh/custom}"
  THEME_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
  if [ ! -d "$THEME_DIR" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
  fi

  echo "Setting Powerlevel10k as Zsh theme in .zshrc..."
  ZSHRC="${USER_HOME}/.zshrc"
  if grep -q '^ZSH_THEME=' "$ZSHRC"; then
    # Replace existing ZSH_THEME
    sed -i '' 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
  else
    # Add theme line if missing
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
  fi

  echo "Fetching Powerlevel10k config (.p10k.zsh)..."
  curl -L -o "${USER_HOME}/.p10k.zsh" "https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/dotfiles/p10k/.p10k.zsh"

  # Patch .zshrc for instant prompt and sourcing
  patch_zshrc_for_p10k

  echo "Oh My Zsh and Powerlevel10k setup complete."
}

#--------------------#
#  Main entrypoint   #
#--------------------#
main() {
  install_prereqs
  install_iterm2_and_font
  install_zsh_and_p10k
  # Call more install functions here: install_neovim, install_tmux, etc.

  echo
  echo "🎉 All done! Open iTerm2 and finish importing your profile and colors as instructed above."
}

main "$@"
