# Powerlevel10k — My Prompt Reference

This is a living README for my `.p10k.zsh`. It captures **what my prompt shows**, **why**, and **how to tweak it quickly** without re-running the wizard every time.

---

## TL;DR

- **Style:** lean, single line, Nerd Font icons  
- **Instant prompt:** verbose (enabled)  
- **Transient prompt:** off  
- **Left prompt:** `context  dir  vcs  prompt_char`  
- **Right prompt:** `status  exec_time  bg_jobs  [tool/env segments…]`  
- **Custom bits:** OS‑aware prompt symbol, smart 2‑segment path, compact Git formatter

To re-run the wizard safely:
```zsh
p10k configure
# This rewrites ~/.p10k.zsh. Keep custom code in ~/.p10k.local.zsh (see below),
# so you can re-run the wizard without losing your tweaks.
```

---

## Layout & Behavior

### Left prompt elements
Order is set by `POWERLEVEL9K_LEFT_PROMPT_ELEMENTS`:
```
context  dir  vcs  prompt_char
```
- **context** — `username@host` with OS‑tinted username color. Linux adds a trailing `:` to match common shells.
- **dir** — Shows **only the last two segments** for long paths with a grey `../` ellipsis (example: `~/…/src/pkg`). Home is `~`.
- **vcs** — Compact Git status (branch/tag/commit + ahead/behind, staged/unstaged/untracked, action/conflicts, stashes).
- **prompt_char** — Symbol depends on OS: macOS `%%`, Linux `$`, Windows `>`.

### Right prompt elements
Order is set by `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`:
```
status  command_execution_time  background_jobs  direnv  asdf
virtualenv  anaconda  pyenv  goenv  nodenv  nvm  nodeenv
rbenv  rvm  fvm  luaenv  jenv  plenv  perlbrew  phpenv
scalaenv  haskell_stack  kubecontext  terraform  aws  aws_eb_env
azure  gcloud  google_app_cred  toolbox  nordvpn  ranger  yazi
nnn  lf  xplr  vim_shell  midnight_commander  nix_shell  chezmoi_shell
todo  timewarrior  taskwarrior  per_directory_history
```
> Many of these are conditional; they appear only if relevant for the current directory/session.

### Global look & feel
- **Single line** prompt: `POWERLEVEL9K_PROMPT_ADD_NEWLINE=false`
- No extra whitespace or end-of-line symbols; segments separated by plain space.
- Icons placed **before** content; background is transparent.
- **Colors** are mostly soft/neutral until a segment is active.

---

## Customizations Worth Remembering

### 1) OS‑aware prompt symbol
```zsh
case "$OSTYPE" in
  darwin*) PROMPT_SYMBOL='%%' ;;
  linux-gnu*) PROMPT_SYMBOL='$' ;;
  cygwin*|msys*) PROMPT_SYMBOL='>' ;;
  *) PROMPT_SYMBOL='$' ;;
esac

POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION="${PROMPT_SYMBOL}"
POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION="${PROMPT_SYMBOL}"
POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
```
**Why:** Instant context cue for OS without reading host.

### 2) Smart, short path (last 2 segments)
Path display uses `_p10k_last2_or_parent` and injects it via:
```zsh
POWERLEVEL9K_DIR_CONTENT_EXPANSION='${$(_p10k_last2_or_parent)}'
```
Behavior:
- `~` for home
- `~/a/b` or `~/…/y/z` for deeper paths (with grey `../` ellipsis)
- Absolute non-home paths keep last two segments as `../y/z`

### 3) Compact Git formatter (`my_git_formatter`)
You’ll see, for example:
- Branch or tag (truncated mid‑section if >32 chars)
- `⇣`/`⇡` behind/ahead counts, `⇠`/`⇢` for push diverge
- `+` staged, `!` unstaged, `?` untracked, `~` conflicts, `*` stashes
- `wip` if commit summary matches WIP
- Fades to grey while loading

It’s wired via:
```zsh
POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(1)))+${my_git_format}}'
POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='${$((my_git_formatter(0)))+${my_git_format}}'
```

### 4) Dir shortening rules
- Anchor markers (e.g., `.git`, `package.json`, `Cargo.toml`, etc.) influence truncation boundaries.
- `POWERLEVEL9K_SHORTEN_DIR_LENGTH=2`
- `POWERLEVEL9K_DIR_MAX_LENGTH=80` columns
- `POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false`

### 5) Context coloring and suffix
- Username color changes with OS; root forces a high‑visibility color.
- Linux adds a trailing `:` to the `context` segment for that classic TTY feel.

### 6) Execution time
- Only shows when the last command took **≥ 3s** (precision 0s).

---

## Quick Toggles (copy/paste friendly)

### Prompt density
```zsh
# One line (current)
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

# If you ever want a visually separated 2‑line prompt:
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=
typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=
```

### Transient prompt after Enter
```zsh
# Keep full prompt in history (current)
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off

# Or collapse old prompts to a single character:
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
```

### Instant prompt noise
If tools print during shell init, you might see warnings. To quiet them **without** disabling instant prompt:
```zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose  # (current)
# If needed:
# typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
# typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
```

### Show/hide env/tool versions
```zsh
# Example: only show Node version when project has a version file
typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true

# Example: show Python version only when relevant
typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
typeset -g POWERLEVEL9K_PYENV_SHOW_SYSTEM=true
```

### Git thresholds & colors
```zsh
# Always show counts; set to small values if you want to clamp
typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1

# Clean / modified / untracked colors
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=80
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=74
```

---

## Keep Custom Code Safe from the Wizard

Put your local tweaks in `~/.p10k.local.zsh` and source it **at the end** of `.p10k.zsh`:
```zsh
# ~/.p10k.zsh (append this near the end)
[[ -r ~/.p10k.local.zsh ]] && source ~/.p10k.local.zsh
```
Then move functions (like `_p10k_last2_or_parent` and `my_git_formatter`), OS‑aware symbol logic, or any experimental overrides into `~/.p10k.local.zsh`. Now you can run `p10k configure` anytime without losing changes.

---

## Symbols & Indicators Cheat Sheet

- **Prompt:** `%%` macOS, `$` Linux, `>` Windows
- **Status:** ✔ ok, ✘ error; exit codes shown when non‑zero
- **Git:** `⇡/⇣` ahead/behind, `⇢/⇠` push diverge, `+ ! ? ~ *` staged/unstaged/untracked/conflicted/stash
- **Path:** last two segments with `../` ellipsis for deep paths
- **Timing:** shown when command ≥ **3s**
- **Context:** `user@host` (Linux adds `:`)

---

## Notes

- Segments like `asdf`, `pyenv`, `gcloud`, `kubecontext`, etc., only display when relevant (installed, active, or detected in the project).  
- Colors are numeric xterm‑256 codes; tweak to taste.  
- Background is intentionally transparent to inherit terminal theme.

---

## One-liners I used/liked

Delete all comment lines (in Vim command-line mode):
```:g/^\s*#/d```

Print 0–255 color map:
```zsh
for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ; (( (i+1) % 16 == 0 )) && echo; done
```

---

## Appendix: Segment Lists (verbatim)

```zsh
# Left
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  context dir vcs prompt_char
)

# Right
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status command_execution_time background_jobs direnv asdf virtualenv anaconda
  pyenv goenv nodenv nvm nodeenv rbenv rvm fvm luaenv jenv plenv perlbrew phpenv
  scalaenv haskell_stack kubecontext terraform aws aws_eb_env azure gcloud
  google_app_cred toolbox nordvpn ranger yazi nnn lf xplr vim_shell
  midnight_commander nix_shell chezmoi_shell todo timewarrior taskwarrior
  per_directory_history
)
```
