# Helix: macOS/Linux Bootstrap with Ansible

Personal “machine bootstrapper” for macOS (local or remote) and a minimal Linux baseline. It ensures Homebrew, common CLI tools, **Ghostty** (terminal), Zsh (Orbit or Starship prompt), a preconfigured Neovim (lazy.nvim), tmux (+ TPM), optional Apple SF fonts, and Poetry environments for selected projects.

> **Config is now Bindu-first.** `~/.config` is managed by your **Bindu** repo (cloned directly into `~/.config`). The old `dotfiles/` folder is no longer used.

---

## Table of Contents

- [Repo structure](#repo-structure)
- [System requirements](#system-requirements)
- [Quick start (curl one-liners)](#quick-start-curl-one-liners)
- [Usage guide (helper scripts)](#usage-guide-helper-scripts)
  - [Pick a version: `--version`, `--ref`, `--dev`](#pick-a-version---version---ref---dev)
  - [Run a subset with tags](#run-a-subset-with-tags)
  - [Dry-run and diagnostics](#dry-run-and-diagnostics)
  - [Desktop apps only](#desktop-apps-only)
  - [Poetry envs](#poetry-envs)
  - [SSH config helper](#ssh-config-helper)
- [Direct Ansible usage](#direct-ansible-usage)
- [Roles overview & common tags](#roles-overview--common-tags)
- [Variables & customization](#variables--customization)
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
│     ├─ apple_sf_fonts/
│     ├─ bindu_config_repo/
│     ├─ desktop_apps/
│     ├─ eza/
│     ├─ ghostty/
│     ├─ helix_config_worktree/    # kept for reference; Bindu is primary now
│     ├─ home_shims/
│     ├─ iterm/
│     ├─ linux_bootstrap/
│     ├─ macos_bootstrap/
│     ├─ nvim/
│     ├─ orbit/
│     ├─ poetry_envs/
│     ├─ python_toolchain/
│     ├─ starship/
│     ├─ tmux_setup/
│     ├─ yazi/
│     ├─ zoxide/
│     ├─ zsh_orbit/
│     ├─ zsh_p10k/
│     └─ zsh_starship/
├─ scripts/
│  ├─ install_ansible_local.sh
│  ├─ install_ansible_remote.sh
│  ├─ install_macos_desktop_apps.sh
│  ├─ run_poetry_envs.sh
│  └─ ssh_config_local.sh
├─ secrets/
│  └─ op_token
├─ LICENSE
└─ README.md
```

> **Note:** `dotfiles/` has been retired. Config now comes from **Bindu** via `roles/bindu_config_repo` (cloned straight into `~/.config`).

---

## System requirements

- **macOS**: Xcode Command Line Tools (`xcode-select --install`). The installer checks and exits cleanly if missing.
- **Linux (Debian/Ubuntu)**: a reachable host via SSH for remote runs.

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

## Usage guide (helper scripts)

### Pick a version — `--version`, `--ref`, `--dev`

The installer resolves which git ref to run:

- `--version X.Y.Z` → tag `vX.Y.Z` (or `X.Y.Z`)
- `--ref <any-ref>` → branch, tag, or SHA
- `--dev <branch>` → development branch (e.g. `main` while testing)

If you pass **nothing**, it auto-detects the **latest semver tag** and uses that.

Examples:

```bash
# Latest stable tag (default behaviour)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)"

# Pin to a release
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --version 0.1.12
# or
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --ref v0.1.12

# Test your dev branch
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- --dev main
```

> The chosen ref is also forwarded to playbooks as `helix_repo_branch`, `helix_main_branch`, and `helix_repo_raw_base` so clones and raw-file fetches are ref-consistent.

### Run a subset with tags

Limit what runs by tag(s). Handy when iterating on one role.

**tmux only** (and use your dev branch):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- \
  --dev main \
  --tags tmux -vv
```

**brew packages only** (ensure `brew_bin` is available when tag-scoping to brew tasks):

```bash
BREW=$([ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- \
  --dev main \
  --tags brew_packages \
  -e brew_bin="$BREW"
```

Other handy tags: `bootstrap`, `python`, `nvim`, `fonts`, `ghostty`, `eza`, `yazi`, `zoxide`, `starship`, `bindu`, `orbit`, `home`, `dotfiles`.

List tags on your machine:

```bash
cd ansible
ansible-playbook -i inventory.yml playbooks/macos_local.yml --list-tags
```

### Dry-run and diagnostics

See which tasks would run for a tag:

```bash
ansible-playbook -i ansible/inventory.yml ansible/playbooks/macos_local.yml \
  --limit $(hostname -s | tr '[:upper:]' '[:lower:]') \
  -t tmux --list-tasks
```

Full dry-run with verbosity:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- \
  --dev main \
  --tags tmux \
  --check -vvv
```

### Desktop apps only

Install/normalize GUI apps independently of base bootstrap:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_macos_desktop_apps.sh)"
```

### Poetry envs

Build Poetry envs for projects from `group_vars/*` (`poetry_projects_macos` / `poetry_projects_linux`):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/run_poetry_envs.sh)"
```

Supports `--limit` and passes through extra Ansible args.

### SSH config helper

Rebuild SSH config locally from repo rules:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/ssh_config_local.sh)"
```

> **Host limiting:** Your `install_ansible_local.sh` auto-detects the current mac’s hostname and applies `--limit` automatically when it finds a matching host in `ansible/inventory.yml`. You can still override with `--limit <host>` yourself.

---

## Direct Ansible usage

From a local checkout:

```bash
cd ansible

# macOS local, limit to current host
ansible-playbook -i inventory.yml playbooks/macos_local.yml --limit eclipse -K

# Only brew packages (tag) — pass brew_bin if necessary
ansible-playbook -i inventory.yml playbooks/macos_local.yml --limit eclipse -K \
  -t brew_packages -e brew_bin=$([ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)

# Desktop apps only
ansible-playbook -i inventory.yml playbooks/desktop_apps.yml --limit eclipse -K

# Poetry envs (macOS & Linux)
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

## Roles overview & common tags

- **macos_bootstrap** — Homebrew install/updates, packages & casks  
  *Tags:* `bootstrap`, `brew`, `brew_packages`, `brew_casks`, `casks`

- **bindu_config_repo** — clone **Bindu** directly into `~/.config` (primary config)  
  *Tags:* `bindu`, `config`

- **orbit** — runtime clone in `~/.orbit` (kept clean on `origin/main`)  
  *Tags:* `orbit`

- **zsh_orbit** / **zsh_p10k** / **starship** — shell prompt setups (pick one or mix)  
  *Tags:* `zsh`, `orbit`, `starship`, `prompt`

- **python_toolchain** — pipx, pyenv versions/globals, nvim host venv  
  *Tags:* `python`, `cli`

- **nvim** — lazy.nvim bootstrap, LSPs via Mason  
  *Tags:* `nvim`

- **tmux_setup** — expects `~/.config/tmux/tmux.conf`; installs **TPM** in `~/.tmux/plugins/tpm`  
  *Tags:* `tmux`

- **eza**, **yazi**, **zoxide**, **ghostty**, **apple_sf_fonts**, **desktop_apps**, **linux_bootstrap** — self-explanatory  
  *Tags:* `eza`, `yazi`, `zoxide`, `ghostty`, `fonts`, `desktop_apps`, `linux_bootstrap`, `bootstrap`

---

## Variables & customization

Most knobs live in `ansible/group_vars` and `ansible/host_vars`.

- **`group_vars/macos.yml`**
  - `brew_packages`, `brew_casks`
  - `pipx_packages`
  - `pyenv_versions`, `pyenv_global`
  - `poetry_projects_macos`
  - `bindu_*` (e.g. `bindu_remote`, `bindu_branch`) for the `bindu_config_repo` role
  - `matrix_root`, `matrix_packages_dir`

- **`group_vars/linux.yml`**
  - `apt_packages`, `poetry_projects_linux`, `yazi_install_scope`, locales

- **`host_vars/<host>.yml`**
  - Per-machine taps/casks, Orbit settings, Bindu branch, etc.

- **Installer env vars** (optional)
  - `HELIX_REPO_URL` (default: this repo)
  - `HELIX_LOCAL_DIR` (default: `~/.cache/helix_checkout`)

---

## Troubleshooting

- **Xcode CLT missing** → `xcode-select --install`, then re-run.
- **Homebrew path issues** → a shellenv line is appended to `~/.zprofile`; open a new shell or `eval "$($(command -v brew) shellenv)"`.
- **`brew_bin is undefined`** when tag-scoping → pass `-e brew_bin="$(command -v brew)"` or tag the brew detection/set‑fact tasks so they run with your tag.
- **Bindu not cloning** → ensure `bindu_remote` is correct and that `~/.config` isn’t some other repo; the role will move aside non‑repo dirs automatically.
- **TPM not installed** → run the `tmux` tag; TPM is installed to `~/.tmux/plugins/tpm` by `roles/tmux_setup`.
- **Dry-run** (`--check`) shows changes for idempotent commands → some modules report “changed” on HEAD fetch or plugin sync; this is expected.

---

## FAQ

**Q: Does the installer auto-limit to the current Mac?**  
**A:** Yes. `install_ansible_local.sh` attempts to match your local hostname to an entry in `ansible/inventory.yml` and applies `--limit` automatically. You can still pass `--limit <host>` explicitly.

**Q: How do I test a single role with my dev branch?**  
**A:** Use `--dev <branch>` plus `--tags <role>`:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/helix/refs/heads/main/scripts/install_ansible_local.sh)" -- \
  --dev main --tags tmux -vv
```

**Q: Can I delete the old `dotfiles/` directory?**  
**A:** Yes. Config is now synced by **Bindu** into `~/.config`. Remove `dotfiles/` when convenient.

---

## License

MIT — see `LICENSE`.

---

*Open a PR for tweaks. Most day‑to‑day changes live in `group_vars/macos.yml`.*
