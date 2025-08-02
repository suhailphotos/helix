#!/usr/bin/env bash

set -euo pipefail

USER_HOME="${HOME}"

#--------------------#
#  Prerequisites     #
#--------------------#
install_prereqs() {
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

#------------------------------#
#  Install font and iTerm2     #
#------------------------------#
install_iterm2_and_font() {
  echo "Installing MesloLGS Nerd Font..."
  brew tap homebrew/cask-fonts
  brew install --cask font-meslo-lg-nerd-font

  echo "Installing iTerm2 via Homebrew..."
  brew install --cask iterm2

  echo "Configuring iTerm2 preferences..."
  IT2_PLIST_URL="https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/iterm/com.googlecode.iterm2.plist"
  IT2_PLIST_PATH="${USER_HOME}/Library/Preferences/com.googlecode.iterm2.plist"
  curl -fsSL "$IT2_PLIST_URL" -o "$IT2_PLIST_PATH"

  # Optionally: tell iTerm2 to always load custom preferences from helix repo folder
  # CUSTOM_PREFS_DIR="${USER_HOME}/Library/CloudStorage/Dropbox/matrix/helix/iterm"
  # defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$CUSTOM_PREFS_DIR"
  # defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

  echo "iTerm2 and font setup complete."
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
  curl -fsSL "https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/iterm/.p10k.zsh" -o "${USER_HOME}/.p10k.zsh"

  echo "Fetching iTerm2 color preset..."
  COLOR_FILE="${USER_HOME}/iterm/suhailTerm2.itermcolors"
  mkdir -p "$(dirname "$COLOR_FILE")"
  curl -fsSL "https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/iterm/suhailTerm2.itermcolors" -o "$COLOR_FILE"

  # DO NOT open iTerm2 or the color preset—avoid popups
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
  echo "🎉 All done! Open iTerm2 and enjoy your custom Zsh + Powerlevel10k environment."
  echo "If you ever want to re-import color schemes, just double-click ${COLOR_FILE}."
}

main "$@"
