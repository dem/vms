#!/bin/bash
# Rewrite PS1 in the given bashrc files to color \u@\h with the supplied hex.
# Empty hex → write the default Arch PS1 (no color).
#
# Usage: set-prompt-color.sh <hex|""> <bashrc> [<bashrc>...]
set -e

hex="${1-}"
shift

if [[ -n "$hex" ]]; then
    r=$((0x${hex:1:2}))
    g=$((0x${hex:3:2}))
    b=$((0x${hex:5:2}))
    ps1="PS1='[\\[\\e[38;2;${r};${g};${b}m\\]\\u@\\h\\[\\e[0m\\] \\W]\\\$ '"
else
    ps1="PS1='[\\u@\\h \\W]\\\$ '"
fi

for bashrc in "$@"; do
    [[ -f "$bashrc" ]] || continue
    sed -i '/^PS1=/d' "$bashrc"
    echo "$ps1" >> "$bashrc"
done
