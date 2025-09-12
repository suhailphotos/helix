CONDA_ROOT="$(conda info --base)"

# Clean any older variants
rm -f "$CONDA_ROOT/etc/conda/activate.d/98-ghostty-terminfo."{sh,zsh} \
      "$CONDA_ROOT/etc/conda/deactivate.d/98-ghostty-terminfo."{sh,zsh}
find "$CONDA_ROOT/envs" -type l -name '98-ghostty-terminfo.*' -exec rm -f {} +

# Ensure hook dirs exist
mkdir -p "$CONDA_ROOT/etc/conda/activate.d" "$CONDA_ROOT/etc/conda/deactivate.d"

# --- ACTIVATE: compile per-env with that env's tic; point TERMINFO at the env ---
cat > "$CONDA_ROOT/etc/conda/activate.d/98-ghostty-terminfo.sh" <<'SH'
# Make Ghostty terminfo work in this conda env
if [ "$TERM" = "xterm-ghostty" ]; then
  src="$HOME/.terminfo-src/xterm-ghostty.src"
  if [ -f "$src" ]; then
    mkdir -p "$CONDA_PREFIX/share/terminfo"
    # Use this env's tic if present, fallback to system tic
    if [ -x "$CONDA_PREFIX/bin/tic" ]; then
      "$CONDA_PREFIX/bin/tic" -x -o "$CONDA_PREFIX/share/terminfo" "$src" >/dev/null 2>&1 || true
    else
      tic -x -o "$CONDA_PREFIX/share/terminfo" "$src" >/dev/null 2>&1 || true
    fi
    # Remember previous settings and force this env's database
    export _OLD_TERMINFO="${TERMINFO-}"
    export _OLD_TERMINFO_DIRS="${TERMINFO_DIRS-}"
    export TERMINFO="$CONDA_PREFIX/share/terminfo"
    unset TERMINFO_DIRS
  fi
fi
SH

# --- DEACTIVATE: restore previous TERMINFO/TERMINFO_DIRS ---
cat > "$CONDA_ROOT/etc/conda/deactivate.d/98-ghostty-terminfo.sh" <<'SH'
if [ -n "${_OLD_TERMINFO-}" ]; then
  export TERMINFO="$_OLD_TERMINFO"
else
  unset TERMINFO
fi
if [ -n "${_OLD_TERMINFO_DIRS-}" ]; then
  export TERMINFO_DIRS="${_OLD_TERMINFO_DIRS}"
else
  unset TERMINFO_DIRS
fi
unset _OLD_TERMINFO _OLD_TERMINFO_DIRS
SH

# Link these hooks into every existing env (so they run for all envs)
conda env list | awk 'NR>2 && $1!~/^#/ {print $NF}' | while IFS= read -r envpath; do
  [ -d "$envpath" ] || continue
  mkdir -p "$envpath/etc/conda/activate.d" "$envpath/etc/conda/deactivate.d"
  ln -sf "$CONDA_ROOT/etc/conda/activate.d/98-ghostty-terminfo.sh"   "$envpath/etc/conda/activate.d/98-ghostty-terminfo.sh"
  ln -sf "$CONDA_ROOT/etc/conda/deactivate.d/98-ghostty-terminfo.sh" "$envpath/etc/conda/deactivate.d/98-ghostty-terminfo.sh"
done
