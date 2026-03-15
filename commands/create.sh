# vms create <name> [--profile <profile>] [--noautologin]

name=""
profile="$VMS_DEFAULT_PROFILE"
noautologin=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) profile="$2"; shift 2 ;;
        --noautologin) noautologin=1; shift ;;
        -v|--verbose) VMS_VERBOSE=1; shift ;;
        -*) die "unknown option: $1" ;;
        *) name="$1"; shift ;;
    esac
done

[[ -z "$name" ]] && die "usage: vms create <name> [--profile <profile>] [--noautologin]"
validate_name "$name"

disk="$VMS_IMAGES/$name.qcow2"
pkg_dir="$VMS_FILESYSTEMS/pkg/$name"

# Check if VM already exists
if virsh dominfo "$name" &>/dev/null; then
    die "VM $name already exists"
fi

# Check if disk already exists
if [[ -f "$disk" ]]; then
    die "Disk $disk already exists"
fi

# Cleanup on failure
cleanup_on_failure() {
    virsh destroy "$name" 2>/dev/null || true
    virsh undefine "$name" --nvram 2>/dev/null || true
    rm -f "$disk"
    sudo rm -rf "$pkg_dir"
    rm -f "$VMS_ROOT/env/vv/$name.vv"
}
trap cleanup_on_failure EXIT

# Ensure Arch ISO is present and fresh, extract kernel/initrd
"$VMS_ROOT/lib/iso.sh"

# Paths for direct kernel boot (extracted from ISO)
kernel_dir="$VMS_ISO/arch-boot"
kernel="$kernel_dir/vmlinuz-linux"
initrd="$kernel_dir/initramfs-linux.img"

# Get ISO UUID for archiso boot
iso_uuid=$(blkid -s UUID -o value "$VMS_ARCH_ISO")
[[ -z "$iso_uuid" ]] && die "Could not determine ISO UUID"

# Allocate static SPICE port
spice_port=$(allocate_spice_port)

info "Creating VM $name profile $profile (SPICE port $spice_port)"

# Create VM-specific package cache directory
step "Creating package cache directory" \
    sudo mkdir -p "$pkg_dir"

# Create disk image
step "Creating disk image" \
    qemu-img create -f qcow2 "$disk" "$VMS_DEFAULT_DISK"

# Create VM with virt-install
step "Defining VM and booting ISO" \
    virt-install \
    --name "$name" \
    --osinfo archlinux \
    --memory "$VMS_DEFAULT_MEMORY" \
    --memorybacking source.type=memfd,access.mode=shared \
    --vcpus "$VMS_DEFAULT_CPUS" \
    --disk "path=$disk,format=qcow2,bus=virtio" \
    --cdrom "$VMS_ARCH_ISO" \
    --boot "uefi,kernel=$kernel,initrd=$initrd,kernel_args=archisobasedir=arch archisosearchuuid=$iso_uuid console=tty0 console=ttyS0,115200n8" \
    --network network=default,model=virtio \
    --filesystem "type=mount,source.dir=$VMS_PKG_CACHE,target.dir=pkg-host,driver.type=virtiofs,readonly=yes" \
    --filesystem "type=mount,source.dir=$pkg_dir,target.dir=pkg,driver.type=virtiofs" \
    --filesystem "type=mount,source.dir=$VMS_ROOT/guest,target.dir=vms,driver.type=virtiofs,readonly=yes" \
    --graphics spice,listen=127.0.0.1 \
    --video qxl \
    --channel spicevmc \
    --serial pty \
    --noautoconsole

# Set static SPICE port (virt-install doesn't support autoport=no, so redefine via XML)
set_spice_port() {
    virsh dumpxml "$name" | \
        sed "s/<graphics type='spice'[^>]*/<graphics type='spice' port='$spice_port' autoport='no' listen='127.0.0.1'/" | \
        virsh define /dev/stdin
}
step "Setting SPICE port $spice_port" set_spice_port

# Generate viewer config
mkdir -p "$VMS_ROOT/env/vv"
sed "s/{{PORT}}/$spice_port/" "$VMS_ROOT/templates/viewer.vv" > "$VMS_ROOT/env/vv/$name.vv"

source "$VMS_ROOT/lib/vm.sh"

step "Waiting for live environment" wait_for_console "$name"

step "Mounting guest scripts" \
    "$VMS_ROOT/lib/console.sh" run "$name" "mkdir -p /vms && mount -t virtiofs vms /vms"

vm_user="$(cat "$VMS_ROOT/env/user")"
vm_uid=""
vm_gid=""
[[ -f "$VMS_ROOT/env/uid" ]] && vm_uid="$(cat "$VMS_ROOT/env/uid")"
[[ -f "$VMS_ROOT/env/gid" ]] && vm_gid="$(cat "$VMS_ROOT/env/gid")"

install_cmd="/vms/install.sh '$name' '$vm_user' '$(cat "$VMS_ROOT/env/root_passwd")' '$(cat "$VMS_ROOT/env/user_passwd")' '$vm_uid' '$vm_gid' '$noautologin'"
install_base_system() {
    local log
    log=$(mktemp)
    trap "rm -f '$log'" RETURN

    info "Installing base system"
    if [[ "$VMS_VERBOSE" == "1" ]]; then
        "$VMS_ROOT/lib/console.sh" run "$@" | tee "$log"
    else
        "$VMS_ROOT/lib/console.sh" run "$@" 2>&1 | tee "$log" | \
            sed -un 's/.*=== \(.*\) ===.*/ \1/p'
    fi || {
        echo "FAILED: Installing base system" >&2
        echo "--- output ---" >&2
        cat "$log" >&2
        exit 1
    }
}
install_base_system "$name" "$install_cmd"

sync_packages() {
    local pkg sig
    for pkg in "$pkg_dir"/*.pkg.tar.zst; do
        [[ -f "$pkg" ]] || continue
        sig="$pkg.sig"
        if [[ -f "$sig" ]] && sudo pacman-key --verify "$sig" "$pkg" &>/dev/null; then
            [[ -f "$VMS_PKG_CACHE/${pkg##*/}" ]] || sudo mv "$pkg" "$sig" "$VMS_PKG_CACHE/"
        fi
    done
    [[ -d "$pkg_dir" ]] && sudo rm -f "$pkg_dir"/*
}
step "Syncing new packages to host cache" sync_packages

step "Stopping VM" stop_vm "$name"

reconfigure_boot() {
    virt-xml "$name" --remove-device --disk device=cdrom
    virsh dumpxml "$name" | sed '/<kernel>/d; /<initrd>/d; /<cmdline>/d' | virsh define /dev/stdin
    virt-xml "$name" --edit --boot hd
}
step "Switching to disk boot" reconfigure_boot

step "Starting VM" virsh start "$name"

step "Waiting for boot" wait_for_boot "$name"

trap - EXIT
info "VM $name ready"
