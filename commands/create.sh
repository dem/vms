# vms create <name> [profile] [--memory MB] [--cpus N] [--displays N]
#                              [--disk size] [--color spec] [--no-color]
#                              [--no-autologin]

parse_hw_flags "$@"
parse_color_flag "${HW_REMAINING[@]+"${HW_REMAINING[@]}"}"
set -- "${COLOR_REMAINING[@]+"${COLOR_REMAINING[@]}"}"
memory=$(memory_to_mb "${HW_MEMORY:-$VMS_DEFAULT_MEMORY}")
cpus="${HW_CPUS:-$VMS_DEFAULT_CPUS}"
displays="${HW_DISPLAYS:-$VMS_DEFAULT_DISPLAYS}"

name=""
profile="$VMS_DEFAULT_PROFILE"
disk_size="$VMS_DEFAULT_DISK"
noautologin=""

positional=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --disk) disk_size="$2"; shift 2 ;;
        --no-autologin) noautologin=1; shift ;;
        -*) die "unknown option: $1" ;;
        *) positional+=("$1"); shift ;;
    esac
done

# qemu-img accepts K/M/G/T suffix; require one for clarity
[[ "$disk_size" =~ ^[0-9]+[KMGTkmgt]$ ]] || \
    die "disk size must have K/M/G/T suffix (e.g. 20G): $disk_size"

name="${positional[0]:-}"
[[ ${#positional[@]} -ge 2 ]] && profile="${positional[1]}"
[[ ${#positional[@]} -gt 2 ]] && \
    die "usage: vms create <name> [profile] [--memory MB] [--cpus N] [--displays N] [--no-autologin]"

[[ -z "$name" ]] && \
    die "usage: vms create <name> [profile] [--memory MB] [--cpus N] [--displays N] [--no-autologin]"
validate_name "$name"

dark_hex=""
[[ -n "$COLOR_SPEC" ]] && dark_hex=$(vms_resolve_color_spec "$COLOR_SPEC" "$name")
bright_hex=""
ansi_code=""
if [[ -n "$dark_hex" ]]; then
    bright_hex=$(vms_color_bright_for "$dark_hex")
    ansi_code=$(vms_color_ansi_for "$dark_hex")
fi

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
    vms_color_clear "$name"
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

# QXL stores every head's scanout framebuffer in vgamem; the 16M default only
# fits one full-HD display, so size it per head (32M each, floor 32M) and keep
# vram/ram >= vgamem as QEMU requires.
vgamem=$(( displays * 32768 ))
(( vgamem < 32768 )) && vgamem=32768
vram=$(( vgamem > 65536 ? vgamem : 65536 ))

info "Creating VM $name"

# Create VM-specific package cache directory
step "Creating package cache directory" \
    sudo mkdir -p "$pkg_dir"

# Create disk image
step "Creating disk image ($disk_size)" \
    qemu-img create -f qcow2 "$disk" "$disk_size"

# Create VM with virt-install
step "Defining VM and booting ISO" \
    virt-install \
    --name "$name" \
    --osinfo archlinux \
    --memory "$memory" \
    --memorybacking source.type=memfd,access.mode=shared \
    --vcpus "$cpus" \
    --disk "path=$disk,format=qcow2,bus=virtio,discard=unmap" \
    --cdrom "$VMS_ARCH_ISO" \
    --boot "uefi,kernel=$kernel,initrd=$initrd,kernel_args=archisobasedir=arch archisosearchuuid=$iso_uuid console=tty0 console=ttyS0,115200n8" \
    --network network=default,model=virtio \
    --filesystem "type=mount,source.dir=$VMS_PKG_CACHE,target.dir=pkg-host,driver.type=virtiofs,readonly=yes" \
    --filesystem "type=mount,source.dir=$pkg_dir,target.dir=pkg,driver.type=virtiofs" \
    --filesystem "type=mount,source.dir=$VMS_ROOT/guest,target.dir=vms,driver.type=virtiofs,readonly=yes" \
    --graphics spice,listen=127.0.0.1 \
    --video "model=qxl,heads=$displays,vgamem=$vgamem,vram=$vram,ram=$vram" \
    --channel spicevmc \
    --serial pty \
    --noautoconsole

# Set static SPICE port (virt-install doesn't support autoport=no, so edit after define)
step "Setting SPICE port $spice_port" \
    virt-xml "$name" --edit --graphics port="$spice_port"

# Persist color (if any) and generate viewer config
[[ -n "$dark_hex" ]] && vms_color_set "$name" "$dark_hex"

mkdir -p "$VMS_ROOT/env/vv"
sed -e "s/{{PORT}}/$spice_port/" -e "s/{{VM_NAME}}/$name/" \
    "$VMS_ROOT/templates/viewer.vv" > "$VMS_ROOT/env/vv/$name.vv"
[[ -n "$dark_hex" ]] && \
    printf 'header-color=%s\n' "$dark_hex" >> "$VMS_ROOT/env/vv/$name.vv"

source "$VMS_ROOT/lib/vm.sh"

step "Waiting for live environment" wait_for_console "$name"

step "Mounting guest scripts" \
    "$VMS_ROOT/lib/console.sh" run "$name" "mkdir -p /vms && mount -t virtiofs vms /vms"

vm_user="$(cat "$VMS_ROOT/env/user")"
vm_uid=""
vm_gid=""
[[ -f "$VMS_ROOT/env/uid" ]] && vm_uid="$(cat "$VMS_ROOT/env/uid")"
[[ -f "$VMS_ROOT/env/gid" ]] && vm_gid="$(cat "$VMS_ROOT/env/gid")"

install_cmd="/vms/install.sh '$name' '$vm_user' '$(cat "$VMS_ROOT/env/root_passwd")' '$(cat "$VMS_ROOT/env/user_passwd")' '$vm_uid' '$vm_gid' '$noautologin' '$bright_hex' '$ansi_code'"
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

source "$VMS_ROOT/lib/pkg.sh"
step "Syncing new packages to host cache" vms_sync_packages "$pkg_dir"

step "Stopping VM" stop_vm "$name"

reconfigure_boot() {
    virt-xml "$name" --remove-device --disk device=cdrom
    virt-xml "$name" --edit --boot kernel=,initrd=,cmdline=,hd
}
step "Switching to disk boot" reconfigure_boot

step "Starting VM" virsh start "$name"

step "Waiting for boot" wait_for_boot "$name"

if [[ -n "$profile" ]]; then
    profile_script="$VMS_ROOT/guest/profiles/$profile.sh"
    [[ -f "$profile_script" ]] || die "Profile $profile not found"

    apply_profile() {
        "$VMS_ROOT/lib/console.sh" run "$name" "/vms/profiles/$profile.sh '$vm_user'"
    }
    step "Applying profile $profile" apply_profile

    step "Restarting VM" stop_vm "$name"
    step "Starting VM" virsh start "$name"
    step "Waiting for boot" wait_for_boot "$name"
fi

trap - EXIT
info "VM $name ready"
