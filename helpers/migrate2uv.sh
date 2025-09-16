#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO while running: $BASH_COMMAND" >&2' ERR
exec </dev/null

# -----------------------------
# Config (overridable via env)
# -----------------------------
PACKAGES_ROOT="${PACKAGES_ROOT:-/Users/suhail/Library/CloudStorage/Dropbox/matrix/packages}"
HELIX_ROOT="${HELIX_ROOT:-/Users/suhail/Library/CloudStorage/Dropbox/matrix/helix}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-poetry2uv}"
TARGET_PY="${TARGET_PY:-3.11.7}"
MERGE_ON_PASS="${MERGE_ON_PASS:-0}"    # 1 -> merge to main on success
PUSH="${PUSH:-1}"                      # 0 -> local only (no push)
DRY_RUN="${DRY_RUN:-0}"
RUN_TESTS="${RUN_TESTS:-0}"            # 1 -> run pytest (opt-in)
REDO="${REDO:-0}"                      # 1 -> redo venv/lock/sync even if already synced
DETECT_DEBUG="${DETECT_DEBUG:-0}"      # 1 -> print Houdini detection candidates

# Packages included in Stage 1 migration
MIGRATE_PKGS=(
  hdrUtils helperScripts Incept Lumiera notionManager nukeUtils Ledu
  oauthManager ocioTools pythonKitchen usdUtils
  houdiniLab houdiniUtils
)

# Packages explicitly deferred (CUDA/Conda/etc.)
SKIP_PKGS=( ArsMachina pariVaha spotifyAI webUtils )

# Houdini Python location (override if needed)
HOU_PYTHON="${HOU_PYTHON:-}"

# -----------------------------
# CLI flags
# -----------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --pytest | --tests       Run pytest if present (default: off)
  --dry-run                Don't modify repos
  --no-push                Don't push branches
  --merge                  Merge back to main on success
  --pkg <name>             Only process a single package (can repeat)
  --redo | --force         Re-run venv + lock/sync even if already synced
  -h | --help              Show this help
EOF
}

ONLY_PKGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pytest|--tests) RUN_TESTS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-push) PUSH=0 ;;
    --merge) MERGE_ON_PASS=1 ;;
    --redo|--force) REDO=1 ;;
    --pkg) shift; [[ $# -gt 0 ]] || { echo "missing value for --pkg" >&2; exit 2; }; ONLY_PKGS+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done
if (( ${#ONLY_PKGS[@]} )); then
  MIGRATE_PKGS=("${ONLY_PKGS[@]}")
fi

# -----------------------------
# Helpers
# -----------------------------
say()  { echo "==> $*"; }
note() { echo " • $*"; }
warn() { echo " ⚠️  $*" >&2; }
die()  { echo " ❌ $*" >&2; exit 2; }

is_in() { local x="$1"; shift; local e; for e in "$@"; do [[ "$x" == "$e" ]] && return 0; done; return 1; }

detect_brew() { [[ -x /opt/homebrew/bin/brew ]] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew; }

ensure_uv() {
  if ! command -v uv >/dev/null 2>&1; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      say "Installing uv via brew…"
      "$(detect_brew)" install uv
    else
      die "uv not found. Install uv first."
    fi
  fi
}

ensure_python311() {
  say "Ensuring uv has Python $TARGET_PY"
  uv python install "$TARGET_PY" >/dev/null
}

helm_git_ready() { [[ -d "$1/.git" ]] || die "Not a git repo: $1"; }

ensure_branch() {
  local repo="$1"
  ( cd "$repo"
    git fetch --all --tags --prune
    git switch "$BRANCH" 2>/dev/null || { git switch main; git pull --ff-only || true; git switch -c "$BRANCH"; }
    git pull --ff-only "$REMOTE" "$BRANCH" || true
  )
}

maybe_push() {
  local repo="$1"
  (( PUSH )) || return 0
  ( cd "$repo"; git push "$REMOTE" "$BRANCH" || true )
}

maybe_merge_main() {
  local repo="$1"
  (( MERGE_ON_PASS )) || return 0
  ( cd "$repo"
    git switch main
    git pull --ff-only "$REMOTE" main || true
    git merge --no-edit "$BRANCH"
    git push "$REMOTE" main
    say "Merged $BRANCH → main in $repo"
  )
}

# -----------------------------
# Robust Houdini Python detection (mac + linux)
# Honors: HOU_PYTHON, ORBIT_HOUDINI_ROOT, HFS, latest installed
# -----------------------------
autodetect_houdini_python() {
  # 0) explicit
  if [[ -n "$HOU_PYTHON" && -x "$HOU_PYTHON" ]]; then
    (( DETECT_DEBUG )) && echo "[detect] HOU_PYTHON=$HOU_PYTHON" >&2
    echo "$HOU_PYTHON"; return 0
  fi

  # helper: try to pick a python inside a resolved Houdini ROOT dir
  _py_from_root() {
    local root="$1"
    # mac layout: …/Houdini<ver>/Frameworks/Houdini.framework/Versions/Current/Resources/Frameworks/Python.framework/Versions/Current/bin/
    # linux layout: /opt/hfs<ver>/bin/
    local cands=()
    if [[ "$OSTYPE" == darwin* ]]; then
      cands+=("$root/Frameworks/Houdini.framework/Versions/Current/Resources/Frameworks/Python.framework/Versions/Current/bin/python3")
      cands+=("$root/Frameworks/Houdini.framework/Versions/Current/Resources/Frameworks/Python.framework/Versions/Current/bin/python3.11")
      cands+=("$root/Frameworks/Houdini.framework/Versions/Current/Resources/Frameworks/Python.framework/Versions/Current/bin/python3.10")
    else
      cands+=("$root/bin/python3.11" "$root/bin/python3.10" "$root/bin/python3")
    fi
    local p
    for p in "${cands[@]}"; do
      if [[ -x "$p" ]]; then
        (( DETECT_DEBUG )) && echo "[detect] from root: $p" >&2
        echo "$p"; return 0
      fi
    done
    return 1
  }

  # 1) ORBIT_HOUDINI_ROOT
  if [[ -n "${ORBIT_HOUDINI_ROOT:-}" ]]; then
    if py=$(_py_from_root "$ORBIT_HOUDINI_ROOT"); then echo "$py"; return 0; fi
  fi

  # 2) HFS (if Houdini env already sourced)
  if [[ -n "${HFS:-}" && -d "$HFS" ]]; then
    # On mac HFS usually points to …/Frameworks/Houdini.framework/Versions/Current
    if [[ "$OSTYPE" == darwin* ]]; then
      local macroot="${HFS%/Frameworks/Houdini.framework/Versions/Current}"
      if py=$(_py_from_root "$macroot"); then echo "$py"; return 0; fi
      # Some installs set HFS to the “Current” dir already usable:
      local p
      for p in "$HFS/Resources/Frameworks/Python.framework/Versions/Current/bin/python3" \
               "$HFS/Resources/Frameworks/Python.framework/Versions/Current/bin/python3.11" \
               "$HFS/Resources/Frameworks/Python.framework/Versions/Current/bin/python3.10"; do
        [[ -x "$p" ]] && { (( DETECT_DEBUG )) && echo "[detect] from HFS: $p" >&2; echo "$p"; return 0; }
      done
    else
      if py=$(_py_from_root "$HFS"); then echo "$py"; return 0; fi
    fi
  fi

  # 3) Scan standard install roots and pick newest
  shopt -s nullglob
  local roots=()
  if [[ "$OSTYPE" == darwin* ]]; then
    for d in /Applications/Houdini/Houdini* "$HOME/Applications/Houdini"/Houdini*; do
      [[ -d "$d" ]] && roots+=("$d")
    done
  else
    for d in /opt/hfs*; do
      [[ -d "$d" ]] && roots+=("$d")
    done
  fi
  shopt -u nullglob

  if ((${#roots[@]})); then
    # sort by embedded version, pick newest
    local best=""
    best="$(
      for d in "${roots[@]}"; do
        local base="${d##*/}"
        local ver="$base"
        # strip leading token (Houdini / hfs)
        ver="${ver#Houdini}"
        ver="${ver#hfs}"
        echo "$ver $d"
      done | sort -V | tail -n1 | awk '{print $2}'
    )"
    if [[ -n "$best" ]]; then
      if py=$(_py_from_root "$best"); then echo "$py"; return 0; fi
    fi
  fi

  # 4) Nothing worked
  (( DETECT_DEBUG )) && echo "[detect] no Houdini python found" >&2
  echo ""
}

align_requires_python_with() {
  local interp="$1"
  [[ -x "$interp" ]] || return 0
  "$interp" - <<'PY'
import sys, pathlib, tomllib, re
p = pathlib.Path("pyproject.toml")
if not p.exists(): raise SystemExit
txt = p.read_text()
data = tomllib.loads(txt)
proj = data.get("project") or {}
maj, minor = sys.version_info[:2]
new_req = f">={maj}.{minor},<{maj}.{minor+1 if maj==3 else maj+1}.0" if maj==3 else f">={maj}.{minor},<{maj+1}.0"
if proj.get("requires-python") != new_req:
    def esc(s): return s.replace("\\","\\\\").replace('"','\\"')
    if "requires-python" in proj:
        txt = re.sub(r'(?m)^\s*requires-python\s*=\s*".*?"',
                     f'requires-python = "{esc(new_req)}"', txt)
    else:
        txt = re.sub(r'(?m)^\[project\]\s*$',
                     f'[project]\nrequires-python = "{esc(new_req)}"', txt)
    p.write_text(txt)
    print(f"aligned requires-python -> {new_req}")
PY
}

# Detect migration state:
#  - poetry    : has [tool.poetry]            → needs conversion
#  - converted : has [project] but missing .venv or uv.lock → finish steps
#  - synced    : has [project] AND .venv AND uv.lock        → fully done
migration_state() {
  [[ -f pyproject.toml ]] || { echo "none"; return; }
  if grep -q '^\[tool\.poetry\]' pyproject.toml; then echo "poetry"; return; fi
  if grep -q '^\[project\]' pyproject.toml; then
    [[ -f uv.lock && -d .venv ]] && echo "synced" || echo "converted"
    return
  fi
  echo "unknown"
}

# -----------------------------
# Poetry -> PEP 621 converter (caret/tilde -> PEP 440)
# Preserves original [build-system] when present.
# -----------------------------
convert_poetry_to_pep621() {
python <<'PY'
import re, sys, pathlib, shutil
try:
    import tomllib
except Exception:
    print("tomllib not available; cannot convert", file=sys.stderr)
    sys.exit(2)

def parse_authors(lst):
    out=[]
    for a in lst or []:
        a=a.strip()
        m=re.match(r"^(.*?)\s*<([^>]+)>$", a)
        if m:
            name, email=m.group(1).strip(), m.group(2).strip()
            d={"name":name}
            if email: d["email"]=email
            out.append(d)
        elif a:
            out.append({"name":a})
    return out

_VER = re.compile(r'^([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?([A-Za-z0-9.\-\+]+)?$')
def _split_version(ver: str):
    m = _VER.match(ver.strip())
    if not m: return None
    return int(m.group(1) or 0), int(m.group(2) or 0), int(m.group(3) or 0), (m.group(4) or "")

def _normalize_one(op: str, ver: str) -> str:
    t = _split_version(ver)
    if not t: return ver
    maj, min_, pat, suf = t
    lower = f"{maj}.{min_}.{pat}{suf}"
    if op == '^':
        if maj > 0:   upper = f"{maj+1}.0.0"
        elif min_>0:  upper = f"0.{min_+1}.0"
        else:         upper = f"0.0.{pat+1}"
    else:
        upper = f"{maj+1}.0.0" if (min_ == 0 and pat == 0) else f"{maj}.{min_+1}.0"
    return f">={lower},<{upper}"

def normalize_spec(spec: str) -> str:
    spec = (spec or "").strip()
    if not spec or spec == "*" or spec.lower() == "any": return ""
    if spec[0] in "^~":
        op = spec[0]; rest = spec[1:].lstrip()
        ver_token = re.split(r'[\s,;]', rest, 1)[0]
        tail = rest[len(ver_token):]
        return _normalize_one(op, ver_token) + tail
    return spec

def normalize_python_req(req: str) -> str:
    parts = [p.strip() for p in (req or "").split("||")]
    out = []
    for part in parts:
        out.append(normalize_spec(part) if part.startswith(("^","~")) else part)
    return " || ".join(filter(None, out))

p=pathlib.Path("pyproject.toml")
if not p.exists():
    print("no pyproject", file=sys.stderr); sys.exit(3)
raw = p.read_text()
data = tomllib.loads(raw)

poetry = data.get("tool",{}).get("poetry")
if not poetry:
    print("no [tool.poetry] section", file=sys.stderr); sys.exit(4)

name        = poetry.get("name")
version     = poetry.get("version","0.0.0")
description = poetry.get("description","")
authors     = parse_authors(poetry.get("authors",[]))
readme      = poetry.get("readme")
license_    = poetry.get("license")
keywords    = poetry.get("keywords",[])

urls_map={}
if poetry.get("homepage"):      urls_map["Homepage"]=poetry["homepage"]
if poetry.get("repository"):    urls_map["Repository"]=poetry["repository"]
if poetry.get("documentation"): urls_map["Documentation"]=poetry["documentation"]

deps = dict(poetry.get("dependencies",{}))
pyreq_raw = None
if "python" in deps:
    pyreq_raw = str(deps.pop("python")).strip()
pyreq = normalize_python_req(pyreq_raw) if pyreq_raw else ""

def fmt_deps(d):
    out=[]
    for name, v in (d or {}).items():
        if isinstance(v, dict):
            version = normalize_spec(v.get("version","").strip())
            markers = v.get("markers")
            extras  = v.get("extras")
            s=name
            if extras: s += "[" + ",".join(extras) + "]"
            if version: s += f" {version}"
            if markers: s += f" ; {markers}"
            out.append(s)
        else:
            s=name
            spec = normalize_spec(str(v).strip()) if v not in (None,"","*") else ""
            if spec: s += f" {spec}"
            out.append(s)
    return sorted(out)

project_deps = fmt_deps(deps)

opt_deps={}
groups = poetry.get("group",{})
if groups:
    for g,gdata in groups.items():
        arr = fmt_deps(gdata.get("dependencies",{}))
        if arr: opt_deps[g] = arr
else:
    old_dev = poetry.get("dev-dependencies",{})
    if old_dev: opt_deps["dev"] = fmt_deps(old_dev)

scripts = poetry.get("scripts",{})
orig_build = data.get("build-system", {})

def esc(s): return s.replace("\\","\\\\").replace('"','\\"')

lines=[]
lines.append('[project]')
lines.append(f'name = "{esc(name)}"')
lines.append(f'version = "{esc(version)}"')
if description: lines.append(f'description = "{esc(description)}"')
if readme:      lines.append(f'readme = "{esc(readme)}"')
lines.append(f'requires-python = "{esc(pyreq or ">=3.11,<4")}"')
if license_:    lines.append(f'license = {{ text = "{esc(license_)}" }}')
if keywords:
    lines.append("keywords = [" + ", ".join(f'"{esc(k)}"' for k in keywords) + "]")
if authors:
    lines.append('authors = [')
    for a in authors:
        if "email" in a:
            lines.append(f'  {{ name = "{esc(a["name"])}", email = "{esc(a["email"])}" }},')
        else:
            lines.append(f'  {{ name = "{esc(a["name"])}" }},')
    lines.append(']')
if urls_map:
    lines.append("[project.urls]")
    for k,v in urls_map.items():
        lines.append(f'{k} = "{esc(v)}"')
if project_deps:
    lines.append("dependencies = [")
    for d in project_deps:
        lines.append(f'  "{esc(d)}",')
    lines.append("]")
if opt_deps:
    lines.append("[project.optional-dependencies]")
    for grp, arr in opt_deps.items():
        lines.append(f'{grp} = [')
        for d in arr:
            lines.append(f'  "{esc(d)}",')
        lines.append("]")
if scripts:
    lines.append("[project.scripts]")
    for k,v in scripts.items():
        lines.append(f'{k} = "{esc(v)}"')

lines.append("")
lines.append("[build-system]")
if orig_build:
    reqs = orig_build.get("requires", [])
    if reqs:
        lines.append("requires = [" + ", ".join(f'"{esc(x)}"' for x in reqs) + "]")
    backend = orig_build.get("build-backend")
    if backend:
        lines.append(f'build-backend = "{esc(backend)}"')
else:
    lines.append('requires = ["poetry-core>=1.0.0"]')
    lines.append('build-backend = "poetry.core.masonry.api"')

lines.append("")
lines.append('# Original [tool.poetry] has been migrated to PEP 621 by migrate2uv.sh')

tmp = pathlib.Path("pyproject.uv.toml")
tmp.write_text("\n".join(lines) + "\n")

bk = pathlib.Path("pyproject.toml.bak.poetry2uv")
if not bk.exists():
    shutil.copyfile("pyproject.toml", bk)
pathlib.Path("pyproject.toml").write_text(tmp.read_text())
print("converted")
PY
}

has_tests() { [[ -d tests || -f pytest.ini || -f tox.ini ]]; }

run_smoke_import() {
  local pkgname
  pkgname="$(python - <<'PY'
import pathlib
src = pathlib.Path("src")
if src.is_dir():
    for p in src.iterdir():
        if p.is_dir() and (p/"__init__.py").exists():
            print(p.name); break
PY
)"
  if [[ -n "$pkgname" ]]; then
    uv run python - <<PY
import ${pkgname}
print("${pkgname} OK")
PY
  fi
}

run_tests_if_opted() {
  (( RUN_TESTS )) || return 0
  if has_tests; then
    if grep -q '^\[project\.optional-dependencies\]' pyproject.toml 2>/dev/null \
       && grep -q '^\s*dev\s*=' pyproject.toml 2>/dev/null; then
      uv sync --group dev || true
    fi
    if ! uv run python -c 'import pytest' >/dev/null 2>&1; then
      uv pip install pytest >/dev/null 2>&1 || true
    fi
    uv run -q pytest -q || return 1
  fi
  return 0
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

# Fix caret/tilde in already-converted files (requires-python + deps)
repair_pep621_versions() {
  [[ -f pyproject.toml ]] || return 0
  python <<'PY'
import re, sys, pathlib
import tomllib

def split_first_token(s: str):
    s = s.lstrip()
    m = re.match(r'([^\s,;]+)(.*)$', s)
    return (m.group(1), m.group(2)) if m else (s, "")

_VER = re.compile(r'^([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?([A-Za-z0-9.\-\+]+)?$')
def _split_version(ver: str):
    m = _VER.match(ver.strip())
    if not m: return None
    return int(m.group(1) or 0), int(m.group(2) or 0), int(m.group(3) or 0), (m.group(4) or "")

def _normalize_one(op: str, ver: str) -> str:
    t = _split_version(ver)
    if not t: return ver
    maj, min_, pat, suf = t
    lower = f"{maj}.{min_}.{pat}{suf}"
    if op == '^':
        if maj > 0:   upper = f"{maj+1}.0.0"
        elif min_>0:  upper = f"0.{min_+1}.0"
        else:         upper = f"0.0.{pat+1}"
    else:
        upper = f"{maj+1}.0.0" if (min_ == 0 and pat == 0) else f"{maj}.{min_+1}.0"
    return f">={lower},<{upper}"

def norm_spec(spec: str) -> str:
    spec = (spec or "").strip()
    if not spec or spec == "*" or spec.lower() == "any": return ""
    if spec[0] in "^~":
        op = spec[0]; rest = spec[1:].lstrip()
        ver_tok, tail = split_first_token(rest)
        return _normalize_one(op, ver_tok) + tail
    return spec

def fix_dep_item(item: str) -> str:
    dep_part, sep, markers = item.partition(';')
    dep_part = dep_part.strip()
    m = re.match(r'^([A-Za-z0-9][A-Za-z0-9._-]*)(\[[^\]]+\])?\s*(.*)$', dep_part)
    if not m: return item
    name, extras, rest = m.groups()
    rest = (rest or "").strip()
    if rest.startswith(('^','~')):
        rest = norm_spec(rest)
    new = f"{name}{extras or ''}" + (f" {rest}" if rest else "")
    return new + (f" ;{markers}" if sep else "")

p = pathlib.Path("pyproject.toml")
txt = p.read_text()
data = tomllib.loads(txt)
proj = data.get("project")
if not proj: sys.exit(0)

changed = False
rp = proj.get("requires-python")
if isinstance(rp, str) and (rp.strip().startswith(('^','~')) or '||' in rp):
    parts = [x.strip() for x in rp.split("||")]
    parts = [norm_spec(x) if x and x[0] in "^~" else x for x in parts]
    newrp = " || ".join(filter(None, parts))
    if newrp != rp:
        proj["requires-python"] = newrp; changed = True

deps = proj.get("dependencies") or []
new_deps = [fix_dep_item(x) for x in deps]
if new_deps != deps:
    proj["dependencies"] = new_deps; changed = True

opt = proj.get("optional-dependencies") or {}
new_opt = {}
for grp, arr in opt.items():
    arr2 = [fix_dep_item(x) for x in (arr or [])]
    new_opt[grp] = arr2
    if arr2 != arr: changed = True
proj["optional-dependencies"] = new_opt

if not changed: sys.exit(0)

def esc(s): return s.replace("\\","\\\\").replace('"','\\"')
out=[]
out.append("[project]")
for key in ("name","version","description","readme","requires-python"):
    if key in proj and isinstance(proj[key], str):
        out.append(f'{key} = "{esc(proj[key])}"')
lic = proj.get("license")
if isinstance(lic, dict) and "text" in lic:
    out.append(f'license = {{ text = "{esc(lic["text"])}" }}')
authors = proj.get("authors") or []
if authors:
    out.append("authors = [")
    for a in authors:
        if isinstance(a, dict) and "name" in a:
            if "email" in a:
                out.append(f'  {{ name = "{esc(a["name"])}", email = "{esc(a["email"])}" }},')
            else:
                out.append(f'  {{ name = "{esc(a["name"])}" }},')
    out.append("]")
keywords = proj.get("keywords") or []
if isinstance(keywords, list) and all(isinstance(x,str) for x in keywords):
    out.append("keywords = [" + ", ".join(f'"{esc(k)}"' for k in keywords) + "]")
classifiers = proj.get("classifiers") or []
if isinstance(classifiers, list) and all(isinstance(x,str) for x in classifiers):
    out.append("classifiers = [" + ", ".join(f'"{esc(c)}"' for c in classifiers) + "]")
maint = proj.get("maintainers") or []
if maint:
    out.append("maintainers = [")
    for a in maint:
        if isinstance(a, dict) and "name" in a:
            if "email" in a:
                out.append(f'  {{ name = "{esc(a["name"])}", email = "{esc(a["email"])}" }},')
            else:
                out.append(f'  {{ name = "{esc(a["name"])}" }},')
    out.append("]")
urls = proj.get("urls") or {}
if isinstance(urls, dict) and urls:
    out.append("[project.urls]")
    for k,v in urls.items():
        if isinstance(v, str):
            out.append(f'{k} = "{esc(v)}"')
deps = proj.get("dependencies") or []
if deps:
    out.append("dependencies = [")
    for d in deps:
        out.append(f'  "{esc(d)}",')
    out.append("]")
opt = proj.get("optional-dependencies") or {}
if opt:
    out.append("[project.optional-dependencies]")
    for grp, arr in opt.items():
        out.append(f"{grp} = [")
        for d in (arr or []):
            out.append(f'  "{esc(d)}",')
        out.append("]")
scripts = proj.get("scripts") or {}
if scripts:
    out.append("[project.scripts]")
    for k,v in scripts.items():
        if isinstance(v, str):
            out.append(f'{k} = "{esc(v)}"')
bs = data.get("build-system", {})
out.append("")
out.append("[build-system]")
reqs = bs.get("requires", [])
if reqs:
    out.append("requires = [" + ", ".join(f'"{esc(x)}"' for x in reqs) + "]")
bb = bs.get("build-backend")
if bb:
    out.append(f'build-backend = "{esc(bb)}"')
out.append("")
out.append('# Original [tool.poetry] has been migrated to PEP 621 by migrate2uv.sh')
p.write_text("\n".join(out) + "\n")
print("repaired caret/tilde specs (requires-python, dependencies, optional-dependencies)")
PY
}

# -----------------------------
# Main
# -----------------------------
[[ "$DRY_RUN" == "1" ]] && say "DRY RUN — no modifications will be written."

ensure_uv
ensure_python311

helm_git_ready "$HELIX_ROOT"; ensure_branch "$HELIX_ROOT"; maybe_push "$HELIX_ROOT"

FAILED=()

for p in "${MIGRATE_PKGS[@]}"; do
  if is_in "$p" "${SKIP_PKGS[@]}"; then
    note "Skipping (deferred): $p"
    continue
  fi
  repo="$PACKAGES_ROOT/$p"
  helm_git_ready "$repo"
  say "$p"

  (
    cd "$repo"
    ensure_branch "$repo"

    [[ "$DRY_RUN" == "1" ]] && { note "dry-run: would process $p"; exit 0; }

    if [[ ! -f pyproject.toml ]]; then
      warn "$p has no pyproject.toml — skipping"
      exit 0
    fi

    # Fix any caret/tilde specs left behind in already-converted files
    repair_pep621_versions || true

    # Decide state
    state="$(migration_state)"
    case "$state" in
      poetry)
        note "State: poetry → converting to PEP 621"
        if convert_poetry_to_pep621; then
          note "PEP 621 conversion done"
        else
          warn "Converter failed; falling back to requirements export"
          if command -v poetry >/dev/null 2>&1; then
            poetry export --with dev --format=requirements.txt -o requirements.lock.txt
          else
            warn "Poetry not found; cannot export. Skipping $p"
            exit 1
          fi
        fi
        ;;
      converted)
        note "State: converted → finishing venv + lock/sync"
        ;;
      synced)
        if (( REDO )); then
          warn "State: synced but --redo given → re-running venv + lock/sync"
        else
          note "Already fully migrated — skipping"
          exit 0
        fi
        ;;
      *)
        warn "State: unknown → proceeding cautiously"
        ;;
    esac

    # Create project venv on requested Python
    if [[ "$p" == "houdiniLab" || "$p" == "houdiniUtils" ]]; then
      HOU="$(autodetect_houdini_python)"
      if [[ -z "$HOU" ]]; then
        warn "Cannot locate Houdini Python. Set HOU_PYTHON (or export ORBIT_HOUDINI_ROOT/HFS) and rerun for $p"
        exit 1
      fi
      align_requires_python_with "$HOU" || true
      uv venv --python "$HOU" .venv
    else
      uv venv --python "$TARGET_PY" .venv
    fi

    # Install deps
    if [[ -f pyproject.toml && "$(grep -c '^\[project\]' pyproject.toml || true)" -gt 0 ]]; then
      uv lock
      uv sync
    elif [[ -f requirements.lock.txt ]]; then
      uv pip install -r requirements.lock.txt
    else
      warn "No dependency spec found for $p"; exit 1
    fi

    # Optional tests; otherwise just do smoke import
    set +e
    if (( RUN_TESTS )); then
      run_tests_if_opted
      code=$?
    else
      run_smoke_import
      code=$?
    fi
    set -e

    if (( code != 0 )); then
      warn "Validation step failed for $p"
      FAILED+=("$p")
      commit_if_changes "migrate: poetry → uv (conversion & venv scaffolding)" || true
      maybe_push "$repo"
      exit 0
    fi

    # Commit & push migration
    commit_if_changes "migrate: poetry → uv (PEP 621 + uv lock/sync; py=$TARGET_PY)" || note "no changes to commit"
    maybe_push "$repo"
    maybe_merge_main "$repo"
  )
done

say "Done. Failures: ${#FAILED[@]}"
((${#FAILED[@]}==0)) || { printf ' - %s\n' "${FAILED[@]}"; exit 1; }
