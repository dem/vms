#!/bin/bash
# Rewrite the PS1 block in the given bashrc files to color \u@\h.
# X11 terminals get the exact truecolor hex; the Linux text console (TERM=linux,
# which has no truecolor) falls back to a 16-color ANSI code so it's still
# tinted. The choice is made when .bashrc is sourced, per terminal.
# Empty hex → plain default PS1 (no color).
#
# Usage: set-prompt-color.sh <hex|""> <ansi|""> <bashrc> [<bashrc>...]
set -e

hex="${1-}"
ansi="${2-}"
shift 2

begin='# >>> vms prompt color >>>'
end='# <<< vms prompt color <<<'

for bashrc in "$@"; do
    [[ -f "$bashrc" ]] || continue
    # Drop our previous block, plus any stray PS1= from /etc/skel.
    sed -i "/$begin/,/$end/d" "$bashrc"
    sed -i '/^PS1=/d' "$bashrc"

    if [[ -n "$hex" ]]; then
        r=$((0x${hex:1:2})); g=$((0x${hex:3:2})); b=$((0x${hex:5:2}))
        ansi_ps1="PS1='[\\[\\e[${ansi}m\\]\\u@\\h\\[\\e[0m\\] \\W]\\\$ '"
        true_ps1="PS1='[\\[\\e[38;2;${r};${g};${b}m\\]\\u@\\h\\[\\e[0m\\] \\W]\\\$ '"
        printf '%s\n' \
            "$begin" \
            'if [ "$TERM" = linux ]; then' \
            "    $ansi_ps1" \
            'else' \
            "    $true_ps1" \
            'fi' \
            "$end" >> "$bashrc"
    else
        printf '%s\n' "$begin" "PS1='[\\u@\\h \\W]\\\$ '" "$end" >> "$bashrc"
    fi
done
