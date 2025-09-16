#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR

# -----------------------------
# Config (overridable via env)
# -----------------------------
PACKAGES_ROOT="${PACKAGES_ROOT:-$HOME/Library/CloudStorage/Dropbox/matrix/packages}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-poetry2uv}"        # migration branch to push changes
TARGET_PY="${TARGET_PY:-3.11.7}"

# Stage-1 packages only (default list below; override via env if needed)
MIGRATE_PKGS=(${MIGRATE_PKGS:-hdrUtils helperScripts Incept Lumiera notionManager nukeUtils Ledu oauthManager ocioTools pythonKitchen usdUtils houdiniLab houdiniUtils})
# Explicitly deferred (never touched)
SKIP_PKGS=(${SKIP_PKGS:-ArsMachina pariVaha spotifyAI webUtils})

# Allow narrowing with --pkg flags
ONLY_PKGS=()

# -----------------------------
# CLI
# -----------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --pkg <name>     Only process the given package (can repeat)
  --no-push        Do not push branch to remote
  --branch NAME    Use a different working branch (default: $BRANCH)
  --py VERSION     Use specific Python for uv venv (default: $TARGET_PY)
  -h | --help      Show this help
EOF
}

PUSH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) shift; [[ $# -gt 0 ]] || { echo "missing value for --pkg" >&2; exit 2; }; ONLY_PKGS+=("$1");;
    --no-push) PUSH=0;;
    --branch) shift; BRANCH="${1:-$BRANCH}";;
    --py) shift; TARGET_PY="${1:-$TARGET_PY}";;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
  shift
done
if (( ${#ONLY_PKGS[@]} )); then MIGRATE_PKGS=("${ONLY_PKGS[@]}"); fi

# -----------------------------
# Helpers
# -----------------------------
say()  { echo "==> $*"; }
note() { echo " • $*"; }
warn() { echo " ⚠️  $*" >&2; }

detect_brew() { [[ -x /opt/homebrew/bin/brew ]] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew; }

is_in() { local x="$1"; shift; local e; for e in "$@"; do [[ "$x" == "$e" ]] && return 0; done; return 1; }

ensure_uv() {
  command -v uv >/dev/null 2>&1 && return 0
  if [[ "$(uname -s)" == "Darwin" ]]; then
    say "Installing uv via brew…"
    "$(detect_brew)" install uv
  else
    echo "Install uv first." >&2; exit 2
  fi
}

ensure_python() {
  say "Ensuring uv has Python $TARGET_PY"
  uv python install "$TARGET_PY" >/dev/null
}

# Avoid cross-project venv warnings like the one you saw with Ledu
clear_active_venv() {
  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    note "Clearing pre-existing venv: $VIRTUAL_ENV"
    PATH="${PATH#${VIRTUAL_ENV}/bin:}"
    unset VIRTUAL_ENV
    hash -r 2>/dev/null || true
  fi
}

ensure_branch() {
  local repo="$1"
  ( cd "$repo"
    git fetch --all --tags --prune >/dev/null
    git switch "$BRANCH" 2>/dev/null || { git switch -q main; git pull --ff-only || true; git switch -c "$BRANCH"; }
    git pull --ff-only "$REMOTE" "$BRANCH" || true
  )
}

commit_if_changes() {
  local msg="$1"
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "$msg"
    return 0
  fi
  return 1
}

patch_pyproject_to_hatchling() {
python <<'PY'
import sys, pathlib, tomllib, re

p = pathlib.Path("pyproject.toml")
if not p.exists(): sys.exit(0)
txt = p.read_text()
data = tomllib.loads(txt)

# 1) Force hatchling backend
txt = re.sub(r'(?ms)^\[build-system\]\s*.*?(?=^\[|\Z)', '', txt)
bs = '\n[build-system]\nrequires = ["hatchling>=1.25"]\nbuild-backend = "hatchling.build"\n'
if not txt.endswith('\n'): txt += '\n'
txt += bs

# 2) Explicit wheel target for src-layout
src = pathlib.Path("src")
pkgs = []
if src.exists():
    for child in src.iterdir():
        if child.is_dir() and (child / "__init__.py").exists():
            pkgs.append(str(child).replace("\\","/"))
if pkgs and re.search(r'(?m)^\[tool\.hatch\.build\.targets\.wheel\]', txt) is None:
    txt += "\n[tool.hatch.build.targets.wheel]\npackages = [\n" + "".join(f'  "{p}",\n' for p in pkgs) + "]\n"

# 3) Drop converter banner (cosmetic)
txt = re.sub(r'(?m)^# Original \[tool\.poetry\].*migrate.*\n?', '', txt)

p.write_text(txt)
print("patched")
PY
}

cleanup_poetry_artifacts() {
  local removed=0
  for f in poetry.lock pyproject.uv.toml pyproject.toml.bak.poetry2uv; do
    if [[ -f "$f" ]]; then
      # prefer removing from git if tracked; else unlink
      if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
        git rm -f "$f" >/dev/null || true
      else
        rm -f "$f" || true
      fi
      removed=1
    fi
  done
  return $removed
}

uvify_repo() {
  local name="$1"
  local repo="$PACKAGES_ROOT/$name"

  if is_in "$name" "${SKIP_PKGS[@]}"; then
    note "Skipping (deferred): $name"
    return 0
  fi
  [[ -d "$repo" ]] || { warn "Missing repo dir: $repo"; return 0; }

  say "$name"
  ( cd "$repo" || return 0
    [[ -f pyproject.toml ]] || { note "no pyproject → skip"; return 0; }

    ensure_branch "$repo"
    clear_active_venv

    local pre_hash; pre_hash="$(git rev-parse --short HEAD)"

    # Modern build backend
    patch_pyproject_to_hatchling >/dev/null && note "build-system → hatchling"

    # Fresh venv/lock/sync
    uv venv --python "$TARGET_PY" .venv
    uv lock
    uv sync

    # Prune Poetry leftovers
    cleanup_poetry_artifacts || true

    commit_if_changes "uvify: hatchling backend, regen uv.lock, prune poetry files (see $pre_hash for old artifacts)" \
      || note "no changes to commit"

    (( PUSH )) && git push "$REMOTE" "$BRANCH" || true
  )
}

# -----------------------------
# Main
# -----------------------------
ensure_uv
ensure_python

for pkg in "${MIGRATE_PKGS[@]}"; do
  uvify_repo "$pkg"
done

say "Done."
