#!/bin/sh
pick() {
  xrandr --current | awk '/ connected primary/{print $1; exit} / connected/{print $1; exit}'
}
OUT="$(pick)"
[ -n "$OUT" ] && xrandr --output "$OUT" --auto
xev -root -event randr | while read; do
  OUT="$(pick)"
  [ -n "$OUT" ] && xrandr --output "$OUT" --auto
done
