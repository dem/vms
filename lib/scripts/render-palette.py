#!/usr/bin/env python3
"""Render the vms color palette as a single table.
Reads the canonical hex values from lib/colors.sh.

Usage:
    python3 lib/scripts/render-palette.py             # to stdout
    python3 lib/scripts/render-palette.py > docs/palette.ansi
"""

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
COLORS_SH = REPO / "lib/colors.sh"
SRC = COLORS_SH.read_text()

names = re.findall(r"\b[a-z]+\b", re.search(r"VMS_COLOR_NAMES=\((.*?)\)", SRC, re.S).group(1))
dark = re.findall(r'"(#[0-9a-fA-F]{6})"', re.search(r"VMS_COLOR_DARK=\((.*?)\)", SRC, re.S).group(1))
bright = re.findall(r'"(#[0-9a-fA-F]{6})"', re.search(r"VMS_COLOR_BRIGHT=\((.*?)\)", SRC, re.S).group(1))


def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def fg(c):
    return f"\033[38;2;{c[0]};{c[1]};{c[2]}m"


def bg(c):
    return f"\033[48;2;{c[0]};{c[1]};{c[2]}m"


RST = "\033[0m"
BLD = "\033[1m"

TERM = (30, 30, 30)
TERM_FG = (200, 200, 200)
WHITE = (255, 255, 255)


print()
print(f"{BLD}vms 16-hue palette (from lib/colors.sh){RST}")
print("  600 → viewer header strip")
print("  300 → PS1 \\u@\\h foreground")
print()
print(
    f"  {'hue':<8}  {'600':<8} {'300':<8} "
    f"{'viewer header':<32}  PS1"
)
print()
BAR_WIDTH = 28
for name, dh, bh in zip(names, dark, bright):
    D = rgb(dh)
    B = rgb(bh)
    pad = " " * (8 - len(name))
    bar = f"  vms-{name}".ljust(BAR_WIDTH)
    header = f"{bg(D)}{fg(WHITE)}{bar}{RST}"
    ps1 = (
        f"{bg(TERM)}{fg(TERM_FG)}["
        f"{fg(B)}user@vms-{name}{fg(TERM_FG)} ~]$ ls -la{pad}{RST}"
    )
    print(f"  {name:<8}  {dh}  {bh}  {header}  {ps1}")
print()


print(f"{BLD}Example explicit assignments (--color <hue>){RST}")
examples = [
    ("dev",     "emerald"),
    ("prod",    "amber"),
    ("web",     "green"),
    ("scratch", "red"),
]
for vm, hue in examples:
    idx = names.index(hue)
    D = rgb(dark[idx])
    B = rgb(bright[idx])
    swatch_d = f"{bg(D)}{fg(WHITE)}  {hue:<8}  {RST}"
    swatch_b = (
        f"{bg(TERM)}{fg(TERM_FG)}["
        f"{fg(B)}user@{vm}{fg(TERM_FG)} ~]$ {RST}"
    )
    print(f"  {vm:<10}  {swatch_d}  {swatch_b}")
print()
