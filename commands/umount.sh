# vms umount <name> <guestdir>

name="${1:-}"
guestdir="${2:-}"
[[ -z "$name" || -z "$guestdir" ]] && die "usage: vms umount <name> <guestdir>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

[[ "$guestdir" == /* ]] || die "Guest directory must be an absolute path"

# Find the virtiofs tag matching this guestdir
# Tags are derived from guestdir: /home/user/projects → home-user-projects (possibly with -N suffix)
base_tag=$(echo "$guestdir" | sed 's|^/||; s|/|-|g')
tag=""
xml=$(virsh dumpxml "$name" 2>/dev/null)
if echo "$xml" | grep -q "dir='$base_tag'"; then
    tag="$base_tag"
else
    for i in $(seq 1 99); do
        if echo "$xml" | grep -q "dir='$base_tag-$i'"; then
            tag="$base_tag-$i"
            break
        fi
    done
fi
[[ -z "$tag" ]] && die "No mount found for $guestdir"

state=$(virsh domstate "$name" 2>/dev/null)

if [[ "$state" == "running" ]]; then
    # Running VM: unmount inside guest + detach device
    source "$VMS_ROOT/lib/vm.sh"

    do_umount() {
        "$VMS_ROOT/lib/console.sh" run "$name" "umount '$guestdir' 2>/dev/null || true"
    }
    step "Unmounting $guestdir" do_umount

    fs_xml=$(mktemp)
    cat > "$fs_xml" <<EOF
<filesystem type='mount'>
  <driver type='virtiofs'/>
  <target dir='$tag'/>
</filesystem>
EOF

    detach_fs() {
        virsh detach-device "$name" "$fs_xml" --live 2>/dev/null || true
        rm -f "$fs_xml"
    }
    step "Detaching filesystem" detach_fs

elif [[ "$state" == "shut off" ]]; then
    # Stopped VM: remove fstab entry first, then XML device.
    # If anything fails mid-way, guest-side change is done first so
    # boot won't try to mount a device that no longer exists.
    disk="$VMS_IMAGES/$name.qcow2"
    [[ -f "$disk" ]] || die "Disk image $disk not found"

    nbd_dev=""
    mnt=$(mktemp -d)

    disconnect_disk() {
        sudo sync
        sudo umount "$mnt" 2>/dev/null || true
        if [[ -n "$nbd_dev" ]]; then
            sudo qemu-nbd -d "$nbd_dev" 2>/dev/null || true
        fi
        rmdir "$mnt" 2>/dev/null || true
    }
    trap disconnect_disk EXIT

    sudo modprobe nbd max_part=8 2>/dev/null || true
    for n in $(seq 0 15); do
        if [[ ! -f "/sys/block/nbd${n}/pid" ]]; then
            nbd_dev="/dev/nbd${n}"
            break
        fi
    done
    [[ -z "$nbd_dev" ]] && die "No free nbd device found"
    sudo qemu-nbd -c "$nbd_dev" "$disk"
    sleep 1
    sudo mount "${nbd_dev}p2" "$mnt"

    sudo sed -i "\|^$tag |d" "$mnt/etc/fstab"

    disconnect_disk
    trap - EXIT

    remove_xml() {
        virt-xml "$name" --remove-device --filesystem target.dir="$tag"
    }
    step "Removing filesystem from VM" remove_xml
else
    die "VM $name is in state '$state' — stop or start it first"
fi

info "Unmounted $guestdir ($tag)"
