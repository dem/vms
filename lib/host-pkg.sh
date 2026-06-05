#!/bin/bash
# Standalone manager for the shared host pacman cache used by vms guests.
# Run manually — NOT part of the `vms` entrypoint. After a manual
# `pacman -Syu` inside a guest, the guest writes new packages to its per-VM
# dir under $VMS_FILESYSTEMS/pkg/<vm>; `sync` pulls the verified ones into the
# shared host cache and clears the guest's per-VM dir. (Pruning old versions
# from the host cache is left to the system, e.g. paccache.timer.)
#
# Usage:
#   host-pkg.sh             show this help
#   host-pkg.sh stats       per-guest and host cache package counts and sizes
#   host-pkg.sh sync        sync + clean up every guest's per-VM cache dir
#   host-pkg.sh sync <vm>   sync + clean up just one guest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/pkg.sh"

die() { echo "error: $*" >&2; exit 1; }
info() { echo "$*"; }

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# --- stats -----------------------------------------------------------------

# Number of .pkg.tar.zst packages in a dir
_pkg_count() {
    shopt -s nullglob
    local a=("$1"/*.pkg.tar.zst)
    shopt -u nullglob
    echo "${#a[@]}"
}

# Disk usage of a dir (human-readable), "-" if missing
_dir_size() {
    [[ -d "$1" ]] || { echo "-"; return; }
    local s
    s=$(du -sh "$1" 2>/dev/null | cut -f1)   # ignore du's exit (may warn on unreadable files)
    echo "${s:-?}"
}

cmd_stats() {
    info "host cache  $VMS_PKG_CACHE"
    printf '  %-16s %5s pkgs  %8s\n' "shared" "$(_pkg_count "$VMS_PKG_CACHE")" "$(_dir_size "$VMS_PKG_CACHE")"

    local base="$VMS_FILESYSTEMS/pkg"
    info ""
    info "guest pending  $base"
    shopt -s nullglob
    local dirs=("$base"/*/)
    shopt -u nullglob
    if [[ ${#dirs[@]} -eq 0 ]]; then
        info "  (none)"
        return 0
    fi
    local d vm n total=0
    for d in "${dirs[@]}"; do
        vm="$(basename "$d")"
        n="$(_pkg_count "$d")"
        total=$((total + n))
        printf '  %-16s %5s pkgs  %8s\n' "$vm" "$n" "$(_dir_size "$d")"
    done
    printf '  %-16s %5s pkgs  %8s\n' "total" "$total" "$(_dir_size "$base")"
}

# --- sync + clean up guest dir ---------------------------------------------

cmd_sync() {
    local base="$VMS_FILESYSTEMS/pkg" vms=("$@") vm
    [[ -d "$base" ]] || die "no guest pkg dirs at $base"
    if [[ ${#vms[@]} -eq 0 ]]; then
        local d
        for d in "$base"/*/; do
            [[ -d "$d" ]] && vms+=("$(basename "$d")")
        done
    fi
    [[ ${#vms[@]} -gt 0 ]] || { info "no guest package dirs to sync"; return 0; }

    for vm in "${vms[@]}"; do
        local dir="$base/$vm"
        [[ -d "$dir" ]] || die "no package dir for '$vm' at $dir"
        local summary left
        summary="$(vms_sync_packages "$dir")"   # moves verified to host, drops cached dups
        # clean up: empty the guest cache dir — leftover files (unverified /
        # partial downloads) and pacman's download-* temp dirs. Keep the dir.
        left=$(_pkg_count "$dir")
        sudo find "$dir" -mindepth 1 -delete
        printf '%s: %s, cleaned %s leftover\n' "$vm" "$summary" "$left"
    done
}

# --- dispatch --------------------------------------------------------------

cmd="${1:-}"
[[ $# -gt 0 ]] && shift
case "$cmd" in
    stats)              cmd_stats "$@" ;;
    sync)               cmd_sync "$@" ;;
    ""|-h|--help|help)  usage ;;
    *)                  die "unknown command: $cmd (try: stats, sync)" ;;
esac
