# vms destroy <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms destroy <name>"
validate_name "$name"

disk="$VMS_IMAGES/$name.qcow2"
pkg_dir="$VMS_FILESYSTEMS/pkg/$name"

if ! virsh dominfo "$name" &>/dev/null; then
    if [[ -f "$disk" ]]; then
        die "VM $name does not exist, but disk remains. Run: rm $disk"
    fi
    die "VM $name does not exist"
fi

info "Destroying VM $name"

# Stop if running
virsh destroy "$name" 2>/dev/null || true

# Undefine (remove nvram too)
virsh undefine "$name" --nvram 2>/dev/null || virsh undefine "$name"

# Remove disk
if [[ -f "$disk" ]]; then
    echo -n "Delete disk $disk? [y/N] "
    read -r answer
    if [[ "$answer" == [yY] ]]; then
        rm -f "$disk"
        info "Removed $disk"
    else
        info "Keeping $disk"
    fi
fi

# Remove package cache directory
if [[ -d "$pkg_dir" ]]; then
    sudo rm -rf "$pkg_dir"
fi

# Remove viewer config
vv_file="$VMS_ROOT/env/vv/$name.vv"
if [[ -f "$vv_file" ]]; then
    rm -f "$vv_file"
fi

info "VM $name destroyed"
