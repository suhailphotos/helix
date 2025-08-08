# helix/ansible — macOS bootstrap (local-first)

This lives **inside your helix repo** so you can version your setup.

## One command (local on `eclipse`)
```bash
cd ansible
bash scripts/install_ansible_local.sh
```
What it does:
1) Ensures Xcode CLT is present (you already installed it).
2) Installs **Homebrew** if missing (non-interactive).
3) Installs **Ansible** with Homebrew.
4) Runs the local play to install CLI tools + iTerm2, Meslo fonts, Oh My Zsh, Powerlevel10k, your templated `.zshrc`, and **copies** `helix/nvim` from GitHub to `~/.config/nvim`.

Manual steps: import iTerm2 profile + colors from `~/Downloads` (downloaded for you).

## Repo structure (excerpt)
```
helix/
├── ansible/
│   ├── inventory.yml
│   ├── group_vars/
│   ├── host_vars/
│   ├── playbooks/
│   ├── roles/
│   └── scripts/
├── nvim/
├── iterm/
└── p10k/
```

## Why keep Ansible in helix?
- Single repo to manage **dotfiles + provisioning**.
- Easy to call from CI or from a controller later (e.g., `flicker`).

## Later: run remotely from a controller
On the controller:
```bash
cd helix/ansible
bash scripts/install_ansible_remote.sh
ansible-playbook -i inventory.yml playbooks/macos_remote.yml --limit eclipse -K
```

## Orbit interaction (sequence correctness)
- This play **installs git + zsh stack first**.
- It then templates `.zshrc` that includes your **Orbit** auto-clone/update (via `ORBIT_*` vars).
- On next shell start, your `.zshrc` will pull Orbit and source `core/bootstrap.zsh`.