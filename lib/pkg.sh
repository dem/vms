# Shared host package-cache helper.
# Assumes VMS_PKG_CACHE is set (from lib/config.sh). Sourced by the package-
# installing commands (create, apply, ...) and by the standalone lib/host-pkg.sh.

# Move signature-verified packages from a guest's per-VM cache dir into the
# shared host cache. New packages are moved in; copies already present in the
# host cache are dropped; unverified packages are left in place with a warning.
# Echoes a one-line summary. Returns 0 even when some packages are skipped.
vms_sync_packages() {
    local pkg_dir="$1" pkg sig name new=0 dup=0 skipped=0
    [[ -d "$pkg_dir" ]] || { echo "no package dir: $pkg_dir"; return 0; }
    shopt -s nullglob
    for pkg in "$pkg_dir"/*.pkg.tar.zst; do
        sig="$pkg.sig"
        name="${pkg##*/}"
        if [[ -f "$sig" ]] && sudo pacman-key --verify "$sig" "$pkg" &>/dev/null; then
            if [[ -f "$VMS_PKG_CACHE/$name" ]]; then
                sudo rm -f "$pkg" "$sig"   # already cached on host, drop guest copy
                dup=$((dup + 1))
            else
                sudo mv "$pkg" "$sig" "$VMS_PKG_CACHE/"
                new=$((new + 1))
            fi
        else
            echo "skipping $name: signature verification failed" >&2
            skipped=$((skipped + 1))
        fi
    done
    shopt -u nullglob
    echo "synced $new new, $dup already-cached, $skipped unverified"
}
