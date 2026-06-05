# 16-hue palette for per-VM identity.
# Source: tailwindcss.com (MIT) — weights 600 and 300
#
# Indices line up across the four arrays.
#   VMS_COLOR_DARK   — viewer header strip bg (and dark-on-light contexts).
#   VMS_COLOR_BRIGHT — truecolor PS1 fg on near-black terminal backgrounds.
#   VMS_COLOR_ANSI   — 16-color ANSI bright code, PS1 fallback on the Linux VT.
#   VMS_COLOR_NAMES  — human-readable hue label.
VMS_COLOR_NAMES=(
    red orange amber yellow lime green emerald teal
    cyan sky blue indigo violet purple fuchsia pink
)
VMS_COLOR_DARK=(
    "#dc2626" "#ea580c" "#d97706" "#ca8a04"
    "#65a30d" "#16a34a" "#059669" "#0d9488"
    "#0891b2" "#0284c7" "#2563eb" "#4f46e5"
    "#7c3aed" "#9333ea" "#c026d3" "#db2777"
)
VMS_COLOR_BRIGHT=(
    "#fca5a5" "#fdba74" "#fcd34d" "#fde047"
    "#bef264" "#86efac" "#6ee7b7" "#5eead4"
    "#67e8f9" "#7dd3fc" "#93c5fd" "#a5b4fc"
    "#c4b5fd" "#d8b4fe" "#f0abfc" "#f9a8d4"
)
# Bright ANSI SGR codes (91-96). 16 hues collapse into 6 buckets — the Linux
# text console has no truecolor, so this is its best approximation.
#   red,orange→91  amber,yellow→93  lime,green,emerald→92
#   teal,cyan,sky→96  blue,indigo→94  violet,purple,fuchsia,pink→95
VMS_COLOR_ANSI=(
    91 91 93 93
    92 92 92 96
    96 96 94 94
    95 95 95 95
)

VMS_COLORS_DIR="$VMS_ROOT/env/colors"

# Stable hash of a VM name to palette index 0..15 — used only for --color auto.
vms_color_index() {
    printf '%d' $(( 0x$(printf '%s' "$1" | md5sum | cut -c1-2) % 16 ))
}

# Resolve a --color spec to a dark hex.
#   auto       → hash <vm> to one of 16 palette dark hexes
#   <name>     → named hue lookup (red, blue, ...)
#   #RRGGBB    → raw hex (validated)
# Echoes the hex; dies on invalid spec.
vms_resolve_color_spec() {
    local spec="$1" vm="$2"
    case "$spec" in
        auto)
            printf '%s' "${VMS_COLOR_DARK[$(vms_color_index "$vm")]}"
            ;;
        \#*)
            [[ "$spec" =~ ^#[0-9a-fA-F]{6}$ ]] \
                || die "invalid color hex: $spec (expected #RRGGBB)"
            printf '%s' "$spec"
            ;;
        *)
            local i
            for i in "${!VMS_COLOR_NAMES[@]}"; do
                if [[ "${VMS_COLOR_NAMES[i]}" == "$spec" ]]; then
                    printf '%s' "${VMS_COLOR_DARK[i]}"
                    return 0
                fi
            done
            die "unknown color: $spec (use one of: ${VMS_COLOR_NAMES[*]}, #RRGGBB, or auto)"
            ;;
    esac
}

# Compute the PS1 (bright) hex for a given dark hex.
# Exact palette match → its paired bright; otherwise mix 50% with white.
vms_color_bright_for() {
    local dark="$1" i
    for i in "${!VMS_COLOR_DARK[@]}"; do
        if [[ "${VMS_COLOR_DARK[i],,}" == "${dark,,}" ]]; then
            printf '%s' "${VMS_COLOR_BRIGHT[i]}"
            return 0
        fi
    done
    local r=$((0x${dark:1:2})) g=$((0x${dark:3:2})) b=$((0x${dark:5:2}))
    printf '#%02x%02x%02x' $(( (r + 255) / 2 )) $(( (g + 255) / 2 )) $(( (b + 255) / 2 ))
}

# Map a dark hex to a bright ANSI SGR code (91-96) for the Linux-VT PS1 fallback.
# Exact palette match → curated code; otherwise bucket by hue angle.
vms_color_ansi_for() {
    local hex="$1" i
    for i in "${!VMS_COLOR_DARK[@]}"; do
        if [[ "${VMS_COLOR_DARK[i],,}" == "${hex,,}" ]]; then
            printf '%s' "${VMS_COLOR_ANSI[i]}"
            return 0
        fi
    done
    # Arbitrary hex (raw --color '#rrggbb'): derive hue, bucket to nearest ANSI.
    local r=$((0x${hex:1:2})) g=$((0x${hex:3:2})) b=$((0x${hex:5:2}))
    local max=$r min=$r
    (( g > max )) && max=$g
    (( b > max )) && max=$b
    (( g < min )) && min=$g
    (( b < min )) && min=$b
    local d=$(( max - min ))
    (( d == 0 )) && { printf '97'; return 0; }   # gray → bright white
    local hue
    if (( max == r )); then
        hue=$(( ( (g - b) * 60 / d + 360 ) % 360 ))
    elif (( max == g )); then
        hue=$(( (b - r) * 60 / d + 120 ))
    else
        hue=$(( (r - g) * 60 / d + 240 ))
    fi
    if   (( hue < 45 || hue >= 345 )); then printf '91'   # red / orange
    elif (( hue < 75 ));  then printf '93'                # yellow
    elif (( hue < 165 )); then printf '92'                # green
    elif (( hue < 200 )); then printf '96'                # cyan
    elif (( hue < 265 )); then printf '94'                # blue
    else printf '95'                                      # magenta / violet
    fi
}

# Storage: env/colors/<vm> contains the resolved dark hex, or is absent.
vms_color_get() {
    local f="$VMS_COLORS_DIR/$1"
    [[ -f "$f" ]] && cat "$f"
}

vms_color_set() {
    mkdir -p "$VMS_COLORS_DIR"
    printf '%s' "$2" > "$VMS_COLORS_DIR/$1"
}

vms_color_clear() {
    rm -f "$VMS_COLORS_DIR/$1"
}

# Copy color file from src to dst (no-op if src has none).
vms_color_copy() {
    local hex
    hex=$(vms_color_get "$1")
    [[ -n "$hex" ]] && vms_color_set "$2" "$hex"
}
