# 1) Locate an existing Ghostty terminfo
for src in "$HOME/.terminfo/x/xterm-ghostty" \
           /usr/share/terminfo/x/xterm-ghostty \
           /lib/terminfo/x/xterm-ghostty; do
  [[ -f "$src" ]] && break
done

# 2) Install/link it into THIS env's terminfo and point TERMINFO there
if [[ -f "$src" ]]; then
  mkdir -p "$CONDA_PREFIX/share/terminfo/x"
  ln -sf "$src" "$CONDA_PREFIX/share/terminfo/x/xterm-ghostty"
  export TERMINFO="$CONDA_PREFIX/share/terminfo"
fi

# 3) Test
infocmp -x xterm-ghostty >/dev/null && echo OK
tput clear
