# vms mount <name> <hostdir> <guestdir> [--readonly] [--temp] [--force]

name="${1:-}"
hostdir="${2:-}"
guestdir="${3:-}"
[[ -z "$name" || -z "$hostdir" || -z "$guestdir" ]] && \
    die "usage: vms mount <name> <hostdir> <guestdir> [--readonly] [--temp] [--force]"
shift 3

readonly_flag=""
temp_flag=""
force_flag=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --readonly) readonly_flag=1; shift ;;
        --temp) temp_flag=1; shift ;;
        --force) force_flag=1; shift ;;
        *) die "unknown option: $1" ;;
    esac
done

validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

# Resolve hostdir to absolute path
hostdir="$(cd "$hostdir" 2>/dev/null && pwd)" || die "Host directory $hostdir does not exist"
[[ -d "$hostdir" ]] || die "Host directory $hostdir does not exist"

# guestdir must be absolute
[[ "$guestdir" == /* ]] || die "Guest directory must be an absolute path"

# Generate virtiofs tag from guest mountpoint
tag=$(echo "$guestdir" | sed 's|^/||; s|/|-|g')
if virsh dumpxml "$name" 2>/dev/null | grep -q "dir='$tag'"; then
    i=1
    while virsh dumpxml "$name" 2>/dev/null | grep -q "dir='$tag-$i'"; do
        ((i++))
    done
    tag="$tag-$i"
fi

state=$(virsh domstate "$name" 2>/dev/null)

if [[ -n "$temp_flag" ]]; then
    # --temp: VM must be running
    [[ "$state" != "running" ]] && die "VM $name is not running (--temp requires a running VM)"

    source "$VMS_ROOT/lib/vm.sh"

    # Shadow check via console
    if [[ -z "$force_flag" ]]; then
        check_result=$("$VMS_ROOT/lib/console.sh" run "$name" \
            "[ -d '$guestdir' ] && [ -n \"\$(ls -A '$guestdir' 2>/dev/null)\" ] && echo SHADOW || echo OK" 2>/dev/null) || true
        if echo "$check_result" | grep -q "SHADOW"; then
            die "$guestdir exists and contains files — mount will shadow them
use --force to proceed"
        fi
    fi

    # Build XML for hotplug
    fs_xml=$(mktemp)
    cat > "$fs_xml" <<EOF
<filesystem type='mount'>
  <driver type='virtiofs'/>
  <source dir='$hostdir'/>
  <target dir='$tag'/>
$([ -n "$readonly_flag" ] && echo "  <readonly/>")
</filesystem>
EOF

    hotplug_fs() {
        virsh attach-device "$name" "$fs_xml" --live
        rm -f "$fs_xml"
    }
    step "Attaching filesystem" hotplug_fs

    mount_opts="defaults"
    [[ -n "$readonly_flag" ]] && mount_opts="ro"
    do_mount() {
        "$VMS_ROOT/lib/console.sh" run "$name" \
            "mkdir -p '$guestdir' && mount -t virtiofs -o '$mount_opts' '$tag' '$guestdir'"
    }
    step "Mounting $guestdir" do_mount

else
    # Persistent: VM must be stopped
    [[ "$state" != "shut off" ]] && die "VM $name must be stopped (use --temp for running VMs)"

    disk="$VMS_IMAGES/$name.qcow2"
    [[ -f "$disk" ]] || die "Disk image $disk not found"

    # Mount guest disk via qemu-nbd first, so we can shadow-check
    # before committing any host-side XML changes. These run directly
    # (not via step) because step uses a subshell which would lose
    # the nbd_dev variable.
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

    # Shadow check — bail before any host-side mutation
    if [[ -z "$force_flag" ]]; then
        if [[ -d "$mnt$guestdir" ]] && [[ -n "$(ls -A "$mnt$guestdir" 2>/dev/null)" ]]; then
            die "$guestdir exists and contains files — mount will shadow them
use --force to proceed"
        fi
    fi

    # Create mountpoint and add fstab entry
    sudo mkdir -p "$mnt$guestdir"
    ro_opt="defaults"
    [[ -n "$readonly_flag" ]] && ro_opt="ro"
    echo "$tag  $guestdir  virtiofs  ${ro_opt},nofail  0 0" | sudo tee -a "$mnt/etc/fstab" >/dev/null

    disconnect_disk
    trap - EXIT

    # Add virtiofs to domain XML (last, after guest-side changes succeeded)
    ro_arg=""
    [[ -n "$readonly_flag" ]] && ro_arg=",readonly=yes"
    add_fs() {
        virt-xml "$name" --add-device --filesystem \
            "type=mount,source.dir=$hostdir,target.dir=$tag,driver.type=virtiofs${ro_arg}"
    }
    step "Adding filesystem to VM" add_fs
fi

info "Mounted $hostdir → $guestdir ($tag)"
