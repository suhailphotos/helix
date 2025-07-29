# Helix

A single home for all my development tools and dotfiles—Neovim (AstroNvim + personal tweaks), tmux, iTerm presets, and helper scripts.  
Clone it, run the installer, and my editing environment is ready on any new machine.

> **Status:** early setup. Folder layout, install scripts, and docs will settle as I migrate configs.  
> For now, Helix is a work-in-progress reference.

---

## What Helix will include

| Area | Contents | Rationale |
| ---- | -------- | --------- |
| `nvim/` | AstroNvim as a plugin, custom Lua options/keymaps, extra plugins (Avante, Telescope, Treesitter, etc.) | Keep third-party code up-to-date with Lazy while isolating my own config |
| `tmux/` | `.tmux.conf`, plugins | Consistent terminal multiplexing on macOS and Linux |
| `iterm/` | Color schemes, profiles | Portable iTerm visuals |
| `scripts/` | `install_mac.sh`, `install_linux.sh`, `update.sh` | One-command bootstrap and updates |

### Why one repo?

* **Atomic installs** – Clone once, symlink with `stow`, and I’m done.  
* **Easy upgrades** – Plugin versions are pinned; bump tags when I want.  
* **Dropbox-friendly** – Lives at `~/Library/CloudStorage/Dropbox/matrix/helix`, leaving my `$HOME` clean except for symlinks.

---

## Quick start (planned)

```bash
git clone https://github.com/suhailec/helix \
  ~/Library/CloudStorage/Dropbox/matrix/helix
cd ~/Library/CloudStorage/Dropbox/matrix/helix/scripts
./install_mac.sh   # or install_linux.sh
```
The script installs dependencies, stows configs, and runs nvim --headless "+Lazy! sync" to pull plugins.

---
### Roadmap
- Finalize folder structure
- Migrate existing Neovim keymaps and options
- Add Avante.nvim with provider config
- Polish tmux settings (OSC52 passthrough, status line)
- Flesh out installer scripts and docs
- Document update workflow (scripts/update.sh)
- Add CI check for broken symlinks / missing deps

---

### License
MIT © Suhail
