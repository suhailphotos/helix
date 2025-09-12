# List the 16 palette-aware color names
ansi_names() {
  print -- "black red green yellow blue purple cyan white"
  print -- "bright-black bright-red bright-green bright-yellow bright-blue bright-purple bright-cyan bright-white"
}

# Show how each palette-aware color renders on YOUR current background,
# with variants: normal | bold | dimmed | italic | underline.
ansi_demo() {
  emulate -L zsh
  local -a base=(black red green yellow blue purple cyan white)
  local -a labels=(normal bold dimmed italic underline)
  local -a attrs=("" "1" "2" "3" "4")    # SGR: 1=bold 2=dim 3=italic 4=underline

  _row() {
    local kind=$1; shift   # "norm" or "bright"
    local prefix=$1; shift # "3" or "9" (SGR FG code families)
    local name idx sgr a
    for name in "$@"; do
      case $name in
        black) idx=0;; red) idx=1;; green) idx=2;; yellow) idx=3;;
        blue) idx=4;; purple) idx=5;; cyan) idx=6;; white) idx=7;;
      esac
      printf "%-13s" "${kind}:${name}"
      for i in {1..${#attrs}}; do
        a=${attrs[i]}
        if [[ -n $a ]]; then
          printf "\e[%s;%s%dm%-9s\e[0m " "$a" "$prefix" "$idx" "${labels[i]}"
        else
          printf "\e[%s%dm%-9s\e[0m " "$prefix" "$idx" "${labels[i]}"
        fi
      done
      echo
    done
  }

  _row norm 3  $base        # 30..37  (palette-aware normal)
  _row bright 9 $base        # 90..97  (palette-aware bright)
}

# Usage (after reloading your shell):
#   ansi_names
#   ansi_demo
