# Helix: macOS/Linux Bootstrap with Ansible

Personal “machine bootstrapper” for macOS (local or remote) and a minimal Linux baseline. It ensures Homebrew, common CLI tools, **Ghostty** (terminal), Zsh (Orbit or Starship prompt), a preconfigured Neovim (lazy.nvim), tmux, optional Apple SF fonts, and Poetry environments for selected projects.

If you’re forking this, the layout is simple, roles are modular, and you can swap packages or add your own roles without fighting the rest of the stack.

---

## Table of Contents

- [Repo structure](#repo-structure)
- [System requirements](#system-requirements)
- [Quick start (curl one-liners)](#quick-start-curl-one-liners)
- [Usage guide (all the ways to run)](#usage-guide-all-the-ways-to-run)
  - [Standard runs via helper scripts](#standard-runs-via-helper-scripts)
  - [Version pinning \u0026 dev branches](#version-pinning--dev-branches)
  - [Tags (run a subset)](#tags-run-a-subset)
  - [Desktop apps only](#desktop-apps-only)
  - [Poetry envs](#poetry-envs)
  - [SSH config helper](#ssh-config-helper)
  - [Direct Ansible usage](#direct-ansible-usage)
- [Roles overview](#roles-overview)
- [Variables \u0026 customization](#variables--customization)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [License](#license)

---

## Repo structure

```
helix/
├─ ansible/
│  ├─ ansible.cfg
│  ├─ collections/requirements.yml
│  ├─ inventory.yml
│  ├─ group_vars/
│  │  ├─ linux.yml
│  │  └─ macos.yml
│  ├─ host_vars/
│  │  ├─ eclipse.yml
│  │  ├─ feather.yml
│  │  ├─ nimbus.yml
│  │  └─ quasar.yml
│  ├─ playbooks/
│  │  ├─ desktop_apps.yml
│  │  ├─ linux_remote.yml
│  │  ├─ macos_local.yml
│  │  ├─ macos_remote.yml
│  │  └─ poetry_envs.yml
│  └─ roles/
│     ├─ macos_bootstrap/      # brew, taps, packages, casks
│     ├─ ghostty/              # terminal (preferred; replacing iTerm)
│     ├─ zsh_orbit/            # minimal zsh that sources Orbit
│     ├─ zsh_p10k/             # oh-my-zsh + powerlevel10k (optional style)
│     ├─ starship/             # starship prompt alternative
│     ├─ python_toolchain/     # pipx, pyenv versions/globals, nvim venv
│     ├─ nvim/                 # lazy.nvim config bootstrap + LSPs
│     ├─ tmux_setup/           # tmux helpers and shim
│     ├─ eza/                  # theme file into ~/.config/eza
│     ├─ yazi/                 # yazi file manager (mac: brew; linux: source)
│     ├─ orbit/                # runtime clone in ~/.orbit
│     ├─ apple_sf_fonts/       # optional Apple SF / New York fonts
│     └─ linux_bootstrap/      # apt baseline + locales
├─ scripts/
│  ├─ install_ansible_local.sh
│  ├─ install_macos_desktop_apps.sh
│  ├─ run_poetry_envs.sh
│  └─ ssh_config_local.sh
└─ dotfiles/ (and other project folders you keep alongside)
```

> **Note:** We’ve transitioned to **Ghostty** as the terminal of choice. iTerm-specific docs were removed from this README.

---

## System requirements

- **macOS**: Xcode Command Line Tools (`xcode-select --install`). The installer checks and aborts with a clear message if missing.
- **Linux (Debian/Ubuntu)**: a reachable host via SSH when running remotely from a controller.

---

## Quick start (curl one-liners)

Default (installs everything **except** Apple SF fonts):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"
```

Include SF fonts:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts
```

Only the SF fonts role:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts
```

Desktop apps (casks) only:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_macos_desktop_apps.sh)"
```

Poetry envs only:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/run_poetry_envs.sh)"
```

SSH config helper:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh)"
```

---

## Usage guide (all the ways to run)

This section consolidates every supported way to run the playbooks—pinning versions, testing dev branches, selecting subsets via tags, and running roles ad‑hoc.

### Standard runs via helper scripts

- **Default install** (no fonts):
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"
  ```

- **Include Apple SF fonts**:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --sf_fonts
  ```

- **Only Apple SF fonts**:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --only_sf_fonts
  ```

- **Desktop apps (casks) only**:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_macos_desktop_apps.sh)"
  ```

- **Poetry envs** (macOS/Linux):
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/run_poetry_envs.sh)"
  ```

- **SSH config helper**:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh)"
  ```

#### Host limiting

Inventory uses hostnames under the `macos` and `linux` groups. Limit to the current machine (e.g. `eclipse`) with `--limit`:

```bash
...install_ansible_local.sh)" -- --limit eclipse
```

### Version pinning & dev branches

The installer supports three mutually exclusive ways to pick the repo ref it should use for the Ansible run:

- `--version X.Y.Z` → checks out tag `vX.Y.Z` (or `X.Y.Z`), e.g.
  ```bash
  ...install_ansible_local.sh)" -- --version 0.1.12
  ```

- `--ref <any git ref>` → branch name, tag name, or commit SHA, e.g.
  ```bash
  ...install_ansible_local.sh)" -- --ref v0.1.12
  ...install_ansible_local.sh)" -- --ref 1a2b3c4d
  ```

- `--dev <branch>` → explicitly use a development branch (e.g. `main` while testing changes), e.g.
  ```bash
  ...install_ansible_local.sh)" -- --dev main
  ```

If you pass **nothing**, the script resolves and uses the **latest semver tag** (e.g. `v0.1.12`) automatically. This lets you keep your bootstrap scripts pinned to a known‑good version without editing them every time you cut a new release.

> The chosen ref is also propagated to playbooks via `helix_repo_branch`, `helix_main_branch`, and `helix_repo_raw_base` so any raw file fetches and helper clones are ref‑consistent.

### Tags (run a subset)

Use Ansible tags to run parts of the macOS bootstrap. Common examples:

- **Only brew packages** (handy when you add `cmake`, `ninja`, etc. to `group_vars/macos.yml`):

  ```bash
  # Compute brew path, then pass it through to ensure the module has brew_bin
  BREW=$([ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" \
    -- --dev main \
       --limit eclipse \
       --tags brew_packages \
       -e brew_bin="$BREW"
  ```

- Other useful tags (from the playbook): `bootstrap`, `python`, `nvim`, `tmux`, `fonts`, `ghostty`, `eza`, `yazi`, `zoxide`, `starship`, `bindu`, `orbit`, `home`, `dotfiles`.

List tags on your machine:

```bash
cd ansible
ansible-playbook -i inventory.yml playbooks/macos_local.yml --limit <host> --list-tags
```

### Desktop apps only

Casks are managed by a dedicated script/playbook so you can install GUI apps independently of the base bootstrap:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_macos_desktop_apps.sh)"
```

### Poetry envs

Build Poetry virtualenvs for the projects listed in `group_vars/*` (`poetry_projects_macos` / `poetry_projects_linux`):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/run_poetry_envs.sh)"
```

Supports `--limit` and passes through additional Ansible args.

### SSH config helper

One‑shot helper to (re)build SSH config locally from your repo rules (script specifics live in `scripts/ssh_config_local.sh`):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh)"
```

### Direct Ansible usage

You can run playbooks directly from a local checkout (helpful for quick experiments):

```bash
cd ansible

# macOS local, limit to current host
ansible-playbook -i inventory.yml playbooks/macos_local.yml --limit eclipse -K

# Only brew packages (tag) and explicitly set brew_bin if needed
ansible-playbook -i inventory.yml playbooks/macos_local.yml --limit eclipse -K \
  -t brew_packages -e brew_bin=$([ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)

# Desktop apps only
ansible-playbook -i inventory.yml playbooks/desktop_apps.yml --limit eclipse -K

# Poetry envs (macOS/Linux)
ansible-playbook -i inventory.yml playbooks/poetry_envs.yml --limit eclipse -K
```

Remote examples (from a controller):

```bash
# macOS remotely (host in inventory under macos group)
ansible-playbook -i ansible/inventory.yml ansible/playbooks/macos_remote.yml --limit eclipse -K

# Linux baseline (Debian/Ubuntu)
ansible-playbook -i ansible/inventory.yml ansible/playbooks/linux_remote.yml --limit nimbus -K
```

---

## Roles overview

- **macos_bootstrap**
  - Verifies Xcode CLT, installs Homebrew (non‑interactive) if missing, adds brew shellenv to `~/.zprofile`.
  - Installs **brew packages** and **casks** from `group_vars/macos.yml`.
  - Tags: `bootstrap`, `brew`, `brew_packages`, `brew_casks`, `casks`.

- **ghostty**
  - Ensures **Ghostty** is installed via Homebrew cask.
  - Tag: `ghostty`.

- **zsh_orbit** / **zsh_p10k** / **starship**
  - Options for your shell prompt setup. Choose one approach or mix:
    - `zsh_orbit`: minimal Zsh sourcing Orbit runtime.
    - `zsh_p10k`: oh‑my‑zsh + Powerlevel10k with templated `.zshrc`.
    - `starship`: Starship prompt via brew or fallback.
  - Tags: `zsh`, `orbit`, `starship`, `prompt`.

- **python_toolchain**
  - Ensures `~/.local/bin` and `pyenv` init in `.zprofile`.
  - Installs `pipx_packages`; installs `pyenv_versions` and sets `pyenv_global`.
  - Creates a dedicated Neovim Python venv (`~/.venvs/nvim`) and installs `pynvim`.
  - Tag: `python`.

- **nvim**
  - Prepares `~/.config` (worktree managed elsewhere), syncs lazy.nvim plugins headlessly, installs common LSPs via Mason.
  - Tag: `nvim`.

- **tmux_setup**
  - Ensures a basic tmux config shim and reloads if inside tmux.
  - Tag: `tmux`.

- **eza**
  - Creates theme/config under `~/.config/eza` (non‑destructive if worktree provides its own).
  - Tag: `eza`.

- **yazi**
  - macOS via brew; Linux builds from source with optional prereqs; installs to system or user scope.
  - Tag: `yazi`.

- **apple_sf_fonts** *(optional)*
  - Attempts to download Apple DMGs; mounts/installs `.pkg` or raw fonts; warns gracefully if login/license is required.
  - Tag: `fonts`.

- **orbit**
  - Clones runtime repo into `~/.orbit` and keeps it clean on `origin/main`; warns if Dropbox dev tree not yet synced.
  - Tag: `orbit`.

- **linux_bootstrap**
  - Apt baseline packages + optional locale setup; symlinks `batcat` → `bat` if needed.
  - Tags: `linux_bootstrap`, `bootstrap`.

---

## Variables & customization

Most knobs live in `ansible/group_vars` and `ansible/host_vars`.

- **`group_vars/macos.yml`**
  - `brew_packages`, `brew_casks` — core CLI and app list.
  - `pipx_packages` — e.g. `poetry`.
  - `pyenv_versions`, `pyenv_global` — Python versions and global default.
  - `poetry_projects_macos` — list of package folders under your `matrix/packages` directory.
  - `helix_repo_*` — how roles fetch raw files/config from this repo.
  - `apple_sf_fonts` — DMG URLs for SF / New York.
  - `matrix_root`, `matrix_packages_dir` — where projects live (Dropbox path by default).

- **`group_vars/linux.yml`**
  - `apt_packages`, `poetry_projects_linux`, `yazi_install_scope`, locales.

- **`host_vars/<host>.yml`**
  - Per-machine taps/casks, Orbit settings, etc.

- **Installer environment variables** (optional)
  - `HELIX_REPO_URL` (default: this repo)
  - `HELIX_BRANCH` (default: `main`)
  - `HELIX_LOCAL_DIR` (default: `~/.cache/helix_checkout`)

Override to point at a fork/branch:

```bash
export HELIX_REPO_URL="https://github.com/yourname/helix.git"
export HELIX_BRANCH="my-feature"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourname/helix/refs/heads/my-feature/scripts/install_ansible_local.sh)"
```

---

## Troubleshooting

- **Xcode CLT missing** → `xcode-select --install` then re-run.
- **Homebrew path** → a shellenv line is appended to `~/.zprofile`. Either open a new shell or `eval "$(/opt/homebrew/bin/brew shellenv)"` once.
- **Apple SF font downloads blocked** → log in to Apple Developer and accept licenses; the role will warn and continue if it can’t download.
- **Tags appear missing** → run `--list-tags` to confirm available tags on your machine. If you only see `[]`, ensure you’re invoking the correct playbook.
- **macOS brew module can’t find brew_bin** → pass `-e brew_bin="$(command -v brew)"` (or use the `BREW=...` snippet shown above).
- **Poetry build can’t find a suitable Python** → ensure `pyenv_versions` are installed and `pyenv_global` is set; the role will pick an interpreter matching the project’s toml spec.
- **Remote runs** → verify SSH connectivity and that `inventory.yml` hostnames match your actual hosts.

---

## FAQ

**Q: How does the installer pick a version?**
A: If you don’t pass `--version`, `--ref`, or `--dev`, it discovers the latest semantic version tag (e.g. `v0.1.12`) and uses that. This avoids hard-coding a tag in your one-liner.

**Q: What does `--dev main` do?**
A: It runs against the `main` branch (or any branch you supply) and also propagates that ref to all helper roles that fetch files from the repo, keeping the run ref-consistent.

**Q: Can I run just one role?**
A: Yes—use tags. For example, `--tags nvim` or `--tags fonts`. See the [Tags](#tags-run-a-subset) section.

**Q: I switched to Ghostty—do I need to remove iTerm?**
A: No code changes are required for a basic run; this README simply reflects the Ghostty-first setup. If you still have the iTerm role checked in, leave it unused or delete it when convenient.

---

## License

MIT — see `LICENSE`.

---

*Questions or improvements?* Open an issue or PR. If you fork it, tweak `group_vars/macos.yml` first—that’s where most day‑to‑day knobs live.

