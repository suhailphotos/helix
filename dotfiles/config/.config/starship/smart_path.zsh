#!/usr/bin/env zsh

# Usage: smart_path.zsh (ell|parent|current)

p=$PWD
h=$HOME

# helper: split into array and depth
typeset -a parts
depth=0
inside_home=0

if [[ "$p" == "$h" ]]; then
  inside_home=1
  parts=()
  depth=0
elif [[ "$p" == $h/* ]]; then
  inside_home=1
  rel=${p#"$h"/}
  parts=("${(@s:/:)rel}")
  depth=${#parts}
else
  abs=${p#/}
  parts=("${(@s:/:)abs}")
  depth=${#parts}
fi

case "$1" in
  ell)
    # print "…/" only when depth >= 3 (home-relative if inside ~)
    (( depth >= 3 )) && print -r -- "…/"
    ;;
  parent)
    # "~/" at depth 1 under ~; "~/<parent>/" at depth 2; "parent/" deeper
    if (( inside_home )); then
      if (( depth == 1 )); then
        print -r -- "~/"
      elif (( depth == 2 )); then
        print -r -- "~/${parts[1]}/"
      elif (( depth >= 3 )); then
        print -r -- "${parts[-2]}/"
      fi
    else
      # outside ~
      [[ ${p:h} != / && ${p:h} != $h ]] && print -r -- "${p:h:t}/"
    fi
    ;;
  current)
    # "~" at ~; otherwise just the basename (cwd)
    if [[ "$p" == "$h" ]]; then
      print -r -- "~"
    else
      print -r -- "${p:t}"
    fi
    ;;
  *)
    # default: be silent
    ;;
esac
