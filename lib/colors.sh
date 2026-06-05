# 16-hue palette for per-VM identity.
# Source: tailwindcss.com (MIT) — weights 600 and 300
#
# Indices line up across the three arrays.
#   VMS_COLOR_DARK   — viewer header strip bg (and dark-on-light contexts).
#   VMS_COLOR_BRIGHT — PS1 fg on near-black terminal backgrounds.
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
