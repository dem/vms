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
ansi = re.findall(r"\b(9[0-7])\b", re.search(r"VMS_COLOR_ANSI=\((.*?)\)", SRC, re.S).group(1))


def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def fg(c):
    return f"\033[38;2;{c[0]};{c[1]};{c[2]}m"


def afg(code):
    return f"\033[{code}m"


def bg(c):
    return f"\033[48;2;{c[0]};{c[1]};{c[2]}m"


RST = "\033[0m"
BLD = "\033[1m"

TERM = (30, 30, 30)
TERM_FG = (200, 200, 200)
WHITE = (255, 255, 255)


print()
print(f"{BLD}vms 16-hue palette (from lib/colors.sh){RST}")
print("  600  → viewer header strip")
print("  300  → PS1 \\u@\\h foreground, truecolor (X11 terminals)")
print("  ANSI → PS1 \\u@\\h foreground, 16-color (Linux text console)")
print()
BAR_WIDTH = 10
print(
    f"  {'hue':<8}  {'600':<8} {'300':<8} {'ANSI':<5} "
    f"{'header':<{BAR_WIDTH}}  {'PS1 (X11)':<18}  PS1 (console)"
)
print()


def ps1_bar(name, pad, color_seq):
    return (
        f"{bg(TERM)}{fg(TERM_FG)}["
        f"{color_seq}user@{name}{fg(TERM_FG)} ~]${pad}{RST}"
    )


for name, dh, bh, code in zip(names, dark, bright, ansi):
    D = rgb(dh)
    B = rgb(bh)
    pad = " " * (8 - len(name))
    header = f"{bg(D)}{fg(WHITE)}{f' {name}'.ljust(BAR_WIDTH)}{RST}"
    ps1_true = ps1_bar(name, pad, fg(B))
    ps1_ansi = ps1_bar(name, pad, afg(code))
    print(f"  {name:<8}  {dh}  {bh}  {code:<5} {header}  {ps1_true}  {ps1_ansi}")
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
    swatch_x11 = f"{bg(TERM)}{fg(TERM_FG)}[{fg(B)}user@{vm}{fg(TERM_FG)} ~]$ {RST}"
    swatch_con = f"{bg(TERM)}{fg(TERM_FG)}[{afg(ansi[idx])}user@{vm}{fg(TERM_FG)} ~]$ {RST}"
    print(f"  {vm:<10}  {swatch_d}  {swatch_x11}  {swatch_con}")
print()
