#!/usr/bin/env bash

# install_mac.sh
# Usage: curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_mac.sh | bash

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

#--------------------#
#  Install iTerm2    #
#--------------------#
install_iterm2() {
  echo "Installing iTerm2 via Homebrew..."
  brew install --cask iterm2

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

  echo "Fetching and importing iTerm2 color preset..."
  COLOR_FILE="${USER_HOME}/iterm/suhailTerm2.itermcolors"
  mkdir -p "$(dirname "$COLOR_FILE")"
  curl -fsSL "https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/iterm/suhailTerm2.itermcolors" -o "$COLOR_FILE"

  # Optionally: auto-import the color preset into iTerm2 by opening it (requires GUI):
  if [ -x "$(command -v open)" ]; then
    open "$COLOR_FILE"
  else
    echo "To import the iTerm2 color scheme, open $COLOR_FILE in iTerm2 manually."
  fi

  echo "iTerm2 setup complete."
}

#--------------------#
#  Main entrypoint   #
#--------------------#
main() {
  install_prereqs
  install_iterm2
  # Call more install functions here: install_neovim, install_tmux, etc.
}

main "$@"
