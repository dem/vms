# Per-VM Colors

Each VM can carry a color identity that shows up in two places: the SPICE
viewer header and the in-guest shell prompt. The color is opt-in, stable
once set, and the same hue is used in both surfaces so they reinforce each
other.

## Why color identity matters

Multiple VMs running side-by-side look identical at a glance. With dozens of
near-identical terminal windows and viewer windows on screen, two recurring
mistakes get expensive fast:

- **Wrong-window typing.** A command meant for the `prod` shell lands in
  `scratch` (or worse, on the host). `rm -rf` does not ask which window.
- **Wrong-window context.** Reading logs, copying credentials, or making a
  change in a VM the user thought was a different VM. Hours of confused
  debugging follow.

A persistent, distinct color per VM is the cheapest possible defense: the
window tells you which VM you're in before you read a single character.

## Palette

16 hues, each with two paired hexes — one mid-dark for the viewer header
(legible on light WM surfaces) and one pastel for the PS1 foreground
(legible on dark terminal backgrounds). The hues:

```
red    orange  amber   yellow  lime   green  emerald  teal
cyan   sky     blue    indigo  violet purple fuchsia  pink
```

Sourced from Tailwind v3, weights `600` and `300`. Defined in
`lib/colors.sh` as `VMS_COLOR_DARK` and `VMS_COLOR_BRIGHT`. You can also
pass a raw hex (`#RRGGBB`) — `vms` will derive a PS1-friendly bright variant
by mixing 50% with white.

To see the palette rendered, run in a truecolor terminal:

```
cat docs/palette.ansi
```

Regenerate after editing `lib/colors.sh`:

```
python3 lib/scripts/render-palette.py > docs/palette.ansi
```

## Approach

### Viewer header

`vms` writes `header-color=#RRGGBB` into the per-VM `.vv` file. virt-viewer
renders a thin colored strip along the top of the window. The key is named
`header-color` so any virt-viewer build that knows the property colors the
header; anything else silently ignores it.

The hex value is the dark variant of the chosen hue, on the rationale that
the viewer's chrome is closer to white than to black.

### PS1

Inside the guest, the user's `~/.bashrc` is rewritten so the `\u@\h` portion
of the default Arch prompt (`[user@host ~]$`) is colored. Only `\u@\h` is
colored; brackets, working directory, and the `$` stay default — the prompt
shape doesn't change, just the identifying substring.

The written block picks the escape per terminal, when `.bashrc` is sourced:

- **X11 terminals** get a 24-bit truecolor code using the bright variant of
  the hue, so the prompt matches the viewer header exactly.
- **The Linux text console** (`TERM=linux`) has no truecolor, so it falls
  back to the nearest 16-color ANSI bright code (`VMS_COLOR_ANSI`). The 16
  hues collapse into ~6 ANSI buckets — approximate, and themed by the
  console palette — but it keeps the prompt tinted there too.

The block is wrapped in `# >>> vms prompt color >>>` markers so re-applying
`--color` replaces it cleanly instead of stacking up.

## Assignment

Color is per-VM and explicit. Set it at create time, or change it later:

```
vms create work          --color blue       # named hue
vms create web           --color '#abcdef'  # raw hex
vms create scratch       --color auto       # stable hash of name
vms clone work alt       --no-color         # clone but drop the color
vms apply  work          --color emerald    # change later
```

Default (no `--color` flag) is no color — same look as upstream
virt-viewer and Arch's default prompt. `clone` and `fork` inherit the
source VM's color unless overridden.

Stored as a single hex string at `env/colors/<vm>`; absent file means "no
color". `destroy` removes it.
