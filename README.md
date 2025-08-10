# Helix: macOS/Linux Bootstrap with Ansible

This repo is my personal “machine bootstrapper.” It sets up a clean macOS (local or remote) or a minimal Linux baseline using Ansible. It installs Homebrew, common CLI tools, iTerm2 + theme/fonts, Zsh + Powerlevel10k, a preconfigured Neovim (lazy.nvim), tmux, and a small Orbit runtime checkout. Apple SF fonts are optional.

If you’re forking this, the layout is simple, roles are modular, and you can swap packages or add your own roles without fighting the rest of the stack.

---

## Contents
- [Repo structure](#repo-structure)
- [Install: quick start](#install-quick-start)
- [Install modes & flags](#install-modes--flags)
- [What the playbooks do](#what-the-playbooks-do)
- [Roles overview](#roles-overview)
- [Variables & customization](#variables--customization)
- [Remote runs](#remote-runs)
- [Neovim config notes](#neovim-config-notes)
- [iTerm2 notes](#iterm2-notes)
- [Add or remove things](#add-or-remove-things)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Repo structure

```
helix/
├─ ansible/
│  ├─ ansible.cfg
│  ├─ collections/requirements.yml      # community.general, etc.
│  ├─ inventory.yml                     # hosts: macOS (eclipse) + linux group
│  ├─ group_vars/
│  │  ├─ linux.yml                      # apt packages
│  │  └─ macos.yml                      # brew packages/casks, pyenv/pipx, urls
│  ├─ host_vars/
│  │  └─ eclipse.yml                    # machine-specific vars (macOS local)
│  ├─ playbooks/
│  │  ├─ macos_local.yml                # local mac bootstrap (this machine)
│  │  ├─ macos_remote.yml               # remote mac hosts (via SSH/inventory)
│  │  └─ linux_remote.yml               # linux baseline (apt)
│  └─ roles/
│     ├─ macos_bootstrap/               # brew, casks, taps, shellenv
│     ├─ zsh_p10k/                      # oh-my-zsh, powerlevel10k, .zshrc
│     ├─ iterm/                         # Meslo fonts + download profile/colors
│     ├─ python_toolchain/              # pipx, pyenv versions/globals
│     ├─ nvim/                          # copy config, pre-sync plugins & LSPs
│     ├─ tmux_setup/                    # minimal ~/.tmux.conf placeholder
│     ├─ apple_sf_fonts/                # optional: install Apple SF fonts
│     ├─ orbit/                         # runtime clone of Orbit repo (~/.orbit)
│     └─ linux_bootstrap/               # apt baseline
├─ iterm/                               # profiles + color presets
├─ nvim/                                # full Neovim config (lazy.nvim-based)
├─ p10k/                                # .p10k.zsh used by Zsh role
├─ scripts/
│  ├─ install_ansible_local.sh          # one-liner entrypoint (macOS local)
│  ├─ install_ansible_remote.sh         # helps prep a controller for remote
│  └─ install_mac.sh                    # older direct shell installer (unused)
└─ secrets/                             # example token file location
```

**Key idea:** everything flows through `ansible/playbooks/*` using modular roles. macOS local is the default path.

---

## Install: quick start

> **Requirements (macOS):** Xcode Command Line Tools. The installer checks this and prompts you if missing.

Run the default (installs everything **except** Apple SF fonts):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"
```

Add SF fonts:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts
```

Only the fonts role:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts
```

Everything (including fonts, future catch‑all):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --all
```

> You can also use the `curl ... | bash -s -- --flag` style if you prefer. The script supports both.

---

## Install modes & flags

The installer (`scripts/install_ansible_local.sh`) accepts:

- `--sf_fonts` — include the Apple SF fonts role.
- `--only_sf_fonts` — run **only** the fonts role (implies `--sf_fonts`).
- `--all` — run everything. (Right now this is the same as default + `--sf_fonts`. Future phases will add more flags.)
- `-h` / `--help` — usage help.

The playbook it runs is `ansible/playbooks/macos_local.yml`. The fonts role is guarded behind a variable so it won’t run unless you pass the flag.

---

## What the playbooks do

**`macos_local.yml`** (default path) runs, in order:

1. `macos_bootstrap` – ensures Homebrew, taps, CLI packages, and casks (`iterm2`, `1password`, etc.). Adds brew shellenv to `~/.zprofile`.
2. `orbit` – clones a runtime-only copy of my Orbit repo into `~/.orbit` (kept clean on `origin/main`). Warns if the Dropbox dev tree isn’t present.
3. `zsh_p10k` – installs Oh My Zsh + Powerlevel10k, drops `.p10k.zsh`, and templates a `.zshrc`.
4. `iterm` – installs MesloLGS Nerd Fonts and downloads iTerm2 profile + color preset into `~/Downloads` for manual import.
5. `python_toolchain` – sets up `pipx` and `pyenv`, installs requested Python versions, sets a global.
6. `nvim` – copies this repo’s `nvim/` into `~/.config/nvim`, removes old packer/harpoon v1 leftovers, creates `~/.vim/undodir`, pre-syncs plugins via lazy.nvim and installs LSPs via Mason in headless mode.
7. `tmux_setup` – ensures a placeholder `~/.tmux.conf` exists.
8. `apple_sf_fonts` *(optional)* – installs Apple San Francisco fonts (requires Apple downloads to be accessible).

**`macos_remote.yml`** mirrors most of the local roles but is designed for remote macs in your inventory.

**`linux_remote.yml`** is a minimal baseline (apt + `tree` by default).

---

## Roles overview

- **macos_bootstrap**
  - Ensures Xcode CLT, installs Homebrew if needed (non‑interactive), adds brew shellenv to `~/.zprofile`.
  - Installs **brew packages** and **casks** from `group_vars/macos.yml`.
  - Uses both idempotent module calls and shell fallbacks for robustness.

- **zsh_p10k**
  - Clones Oh My Zsh and Powerlevel10k.
  - Fetches `.p10k.zsh` from this repo.
  - Templates a `~/.zshrc` from `templates/zshrc.mac.j2`.

- **iterm**
  - Installs MesloLGS Nerd Fonts (4 styles) directly into `~/Library/Fonts`.
  - Downloads an iTerm2 profile JSON and a color preset to `~/Downloads` for manual import.

- **python_toolchain**
  - Ensures `~/.local/bin` PATH and `pyenv` init lines in `~/.zprofile`.
  - Figures out a `pipx` executable (prefer brew), runs `pipx ensurepath`, installs `pipx_packages`.
  - Installs `pyenv_versions` and sets `pyenv_global`.

- **nvim**
  - Copies the repo’s `nvim/` config into place.
  - Cleans old `packer` and Harpoon v1 artifacts.
  - Ensures `~/.vim/undodir` exists.
  - Runs headless `Lazy! sync` and `MasonInstall` for common LSPs.

- **tmux_setup**
  - Creates a minimal `~/.tmux.conf` if you don’t have one.

- **apple_sf_fonts** *(optional)*
  - For each Apple font (SF Pro, Compact, Mono, New York), tries to download the DMG, mount, and install `.pkg` or raw fonts.
  - Gracefully warns if Apple requires login/license and the download is blocked.
  - Tagged `fonts` for `--tags fonts` runs.

- **orbit**
  - Clones a clean runtime repo into `~/.orbit` from variables in `host_vars/eclipse.yml`.

- **linux_bootstrap**
  - Updates apt cache and installs `apt_packages` (very minimal by design).

---

## Variables & customization

Most knobs live in `group_vars` and `host_vars`:

- **`group_vars/macos.yml`**
  - `brew_packages`, `brew_casks` – the core tool list (git, neovim, tmux, ripgrep, etc.).
  - `pipx_packages` – e.g. `poetry`.
  - `pyenv_versions`, `pyenv_global` – Python versions to install and set as global.
  - `helix_repo_*` – how the nvim role fetches this repo (used to copy config).
  - `iterm_profile_json_url`, `iterm_color_preset_url` – where to fetch iTerm resources.
  - `apple_sf_fonts` – list of Apple font names + DMG URLs.

- **`host_vars/eclipse.yml`** (macOS local host):
  - Orbit repo location/branch, optional brew taps/casks to add for this host.

- **`group_vars/linux.yml`**
  - `apt_packages` – minimal baseline packages for Linux hosts.

- **Installer environment variables** (optional):
  - `HELIX_REPO_URL` (default: this repo)
  - `HELIX_BRANCH` (default: `main`)
  - `HELIX_LOCAL_DIR` (default: `~/.cache/helix_bootstrap`)

You can export these before running the installer to point at a fork or a feature branch:

```bash
export HELIX_REPO_URL="https://github.com/yourname/helix.git"
export HELIX_BRANCH="my-branch"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourname/helix/refs/heads/my-branch/scripts/install_ansible_local.sh)"
```

---

## Remote runs

Prepare a controller and get example commands:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_remote.sh)"
```

Then from the checked-out repo (`$HELIX_LOCAL_DIR` printed at the end), run playbooks against your inventory:

```bash
# macOS remote (limit to a host in the macos group)
ansible-playbook -i ansible/inventory.yml ansible/playbooks/macos_remote.yml --limit eclipse -K

# Linux baseline (limit to a host in the linux group)
ansible-playbook -i ansible/inventory.yml ansible/playbooks/linux_remote.yml --limit nimbus -K
```

Edit `ansible/inventory.yml` to add hosts or groups. Put host-specific overrides in `ansible/host_vars/<host>.yml`.

---

## Neovim config notes

- The config is under `nvim/` and uses **lazy.nvim** to manage plugins.
- Bootstrapping is handled by `lua/suhail/lazy_init.lua`.
- Plugins include treesitter, telescope, LSP (mason + lspconfig), cmp, harpoon v2, trouble, undotree, editorconfig, and themes.
- The Ansible role pre-installs plugins (`Lazy! sync`) and common LSPs (`lua-language-server`, `rust-analyzer`, `python-lsp-server`, `typescript-language-server`) in headless mode so first open is fast.

Customize by editing files in `nvim/lua/suhail/lazy/` (e.g. add a plugin file or tweak `lsp.lua`, `telescope.lua`, etc.).

---

## iTerm2 notes

The `iterm` role:
- Installs **MesloLGS Nerd Fonts** to `~/Library/Fonts` (Powerlevel10k recommended font).
- Downloads the profile JSON and color preset to `~/Downloads`. Import them manually:
  1. Preferences → Profiles → Other Actions (gear) → **Import** → `~/Downloads/suhail_item2_profiles.json`
  2. Set the imported profile as **Default**.
  3. Preferences → Profiles → Colors → Color Presets… → **Import** → `~/Downloads/suhailTerm2.itermcolors`
  4. Choose **suhailTerm2** in the preset list.

Apple **San Francisco** fonts are in a separate, optional role (`apple_sf_fonts`) because Apple’s DMGs may require login/license acceptance. If the download is blocked, the role warns and continues.

---

## Add or remove things

### Add a package/cask (macOS)
- Edit `ansible/group_vars/macos.yml`
  - Add to `brew_packages` or `brew_casks`.
- Re-run the installer or run the macOS playbook directly:
  ```bash
  cd ansible && ansible-playbook -i inventory.yml playbooks/macos_local.yml -K
  ```

### Add a new role
1. Create `ansible/roles/<your_role>/tasks/main.yml`.
2. Add it to `ansible/playbooks/macos_local.yml` (or the remote playbook).
3. If it should be optional, guard it:
   ```yaml
   - role: your_role
     when: (enable_your_role | default(false)) | bool
     tags: ['your_tag']
   ```
4. Add a flag in `scripts/install_ansible_local.sh` to set `-e enable_your_role=true` or `--tags your_tag`.

### Remove a role
- Delete it from the playbook’s `roles:` list.
- Optionally remove its variables from `group_vars`/`host_vars`.

### Change iTerm2 profile/colors
- Update the URLs in `group_vars/macos.yml`:
  ```yaml
  iterm_profile_json_url: "https://raw.githubusercontent.com/you/yourrepo/main/iterm/profile.json"
  iterm_color_preset_url: "https://raw.githubusercontent.com/you/yourrepo/main/iterm/colors.itermcolors"
  ```

### Point the installer at your fork/branch
Set the env vars (`HELIX_REPO_URL`, `HELIX_BRANCH`) as shown above.

---

## Troubleshooting

- **Xcode CLT missing**: run `xcode-select --install` first.
- **Homebrew path**: the roles and installer add `eval "$(/opt/homebrew/bin/brew shellenv)"` to `~/.zprofile`. Open a new shell or `eval "$(/opt/homebrew/bin/brew shellenv)"` manually.
- **Apple SF font downloads fail**: log in to Apple Developer and accept licenses, then rerun with `--sf_fonts`. The role skips gracefully if downloads are blocked.
- **Ansible sudo prompts**: playbooks use `-K` to ask for your password. If you see permission errors, rerun and enter sudo when prompted.
- **Neovim headless steps**: they rely on `nvim` and `node` being available (installed via brew). If headless steps fail, open `nvim` once and let lazy.nvim install, then rerun the play.
- **Remote hosts**: ensure SSH access and that `inventory.yml` and `host_vars/*` match the actual hostnames/user setup.

---

## License

This repository is licensed under the **MIT License** (see `LICENSE`).

---

**Questions or improvements?** Open an issue or PR. If you fork it, tweak `group_vars/macos.yml` first—that’s where most of the day‑to‑day knobs live.

