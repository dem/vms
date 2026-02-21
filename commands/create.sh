# vms create <name> [--profile <profile>]

name=""
profile="$VMS_DEFAULT_PROFILE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) profile="$2"; shift 2 ;;
        -v|--verbose) VMS_VERBOSE=1; shift ;;
        -*) die "unknown option: $1" ;;
        *) name="$1"; shift ;;
    esac
done

[[ -z "$name" ]] && die "usage: vms create <name> [--profile <profile>]"

disk="$VMS_IMAGES/$name.qcow2"
pkg_dir="$VMS_FILESYSTEMS/pkg/$name"

# Check if VM already exists
if virsh dominfo "$name" &>/dev/null; then
    die "VM '$name' already exists"
fi

# Check if disk already exists
if [[ -f "$disk" ]]; then
    die "Disk '$disk' already exists"
fi

# Check ISO exists
if [[ ! -f "$VMS_ARCH_ISO" ]]; then
    die "Arch ISO not found at $VMS_ARCH_ISO"
fi

# Paths for direct kernel boot (extracted from ISO)
kernel_dir="$VMS_ISO/arch-boot"
kernel="$kernel_dir/vmlinuz-linux"
initrd="$kernel_dir/initramfs-linux.img"

# Extract kernel/initrd from ISO if not present
if [[ ! -f "$kernel" ]] || [[ ! -f "$initrd" ]]; then
    extract_kernel() {
        sudo mkdir -p "$kernel_dir"
        tmp_mount=$(mktemp -d)
        sudo mount -o loop,ro "$VMS_ARCH_ISO" "$tmp_mount"
        sudo cp "$tmp_mount/arch/boot/x86_64/vmlinuz-linux" "$kernel"
        sudo cp "$tmp_mount/arch/boot/x86_64/initramfs-linux.img" "$initrd"
        sudo umount "$tmp_mount"
        rmdir "$tmp_mount"
    }
    step "Extracting kernel and initrd from ISO" extract_kernel
fi

# Get ISO UUID for archiso boot
iso_uuid=$(blkid -s UUID -o value "$VMS_ARCH_ISO")
[[ -z "$iso_uuid" ]] && die "Could not determine ISO UUID"

info "Creating VM '$name' (profile: $profile)"

# Create VM-specific package cache directory
step "Creating package cache directory" \
    sudo mkdir -p "$pkg_dir"

# Create disk image
step "Creating disk image" \
    qemu-img create -f qcow2 "$disk" "$VMS_DEFAULT_DISK"

# Create VM with virt-install
step "Creating VM" \
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
    --graphics spice,listen=127.0.0.1 \
    --video qxl \
    --channel spicevmc \
    --serial pty \
    --noautoconsole

source "$VMS_ROOT/lib/vm.sh"

step "Waiting for live environment" wait_for_console "$name"

install_base_system() {
    local log
    log=$(mktemp)
    trap "rm -f '$log'" RETURN

    info "Installing base system"
    if [[ "$VMS_VERBOSE" == "1" ]]; then
        "$VMS_ROOT/lib/console.sh" exec "$@" | tee "$log"
    else
        "$VMS_ROOT/lib/console.sh" exec "$@" 2>&1 | tee "$log" | \
            sed -un 's/.*=== \(.*\) ===.*/ \1/p'
    fi || {
        echo "FAILED: Installing base system" >&2
        echo "--- output ---" >&2
        cat "$log" >&2
        exit 1
    }
}
install_base_system "$name" "$VMS_ROOT/guest/install.sh" \
    "$name" "$USER" "$(cat "$VMS_ROOT/env/root_passwd")" "$(cat "$VMS_ROOT/env/user_passwd")"

step "Stopping VM" stop_vm "$name"

reconfigure_boot() {
    virt-xml "$name" --remove-device --disk device=cdrom
    virsh dumpxml "$name" | sed '/<kernel>/d; /<initrd>/d; /<cmdline>/d' | virsh define /dev/stdin
    virt-xml "$name" --edit --boot hd
}
step "Reconfiguring boot" reconfigure_boot

step "Starting VM" virsh start "$name"

step "Waiting for boot" wait_for_boot "$name"

info "VM '$name' ready"
