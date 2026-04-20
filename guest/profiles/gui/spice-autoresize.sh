#!/bin/sh

# Auto-arrange all SPICE virtual displays left-to-right.
# Works for single-display (loop runs once) and multi-head setups.

arrange() {
    # Turn off disconnected outputs so they don't linger with stale frames
    for out in $(xrandr --current | awk '/ disconnected /{print $1}'); do
        xrandr --output "$out" --off 2>/dev/null
    done

    # Arrange connected outputs left-to-right; first becomes primary
    prev=""
    for out in $(xrandr --current | awk '/ connected/{print $1}'); do
        if [ -z "$prev" ]; then
            xrandr --output "$out" --auto --primary --pos 0x0
        else
            xrandr --output "$out" --auto --right-of "$prev"
        fi
        prev="$out"
    done
}

# Apply once at startup
arrange

# Apply again on every RANDR event (resize, connect, disconnect)
xev -root -event randr | while read; do
    arrange
done
