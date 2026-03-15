# vms fork <source> <name>

source="${1:-}"
name="${2:-}"

[[ -z "$source" || -z "$name" ]] && die "usage: vms fork <source> <name>"

source_disk="$VMS_IMAGES/$source.qcow2"
disk="$VMS_IMAGES/$name.qcow2"
pkg_dir="$VMS_FILESYSTEMS/pkg/$name"

# Check source exists
if ! virsh dominfo "$source" &>/dev/null; then
    die "Source VM '$source' does not exist"
fi

if [[ ! -f "$source_disk" ]]; then
    die "Source disk '$source_disk' not found"
fi

# Check target doesn't exist
if virsh dominfo "$name" &>/dev/null; then
    die "VM '$name' already exists"
fi

if [[ -f "$disk" ]]; then
    die "Disk '$disk' already exists"
fi

# Allocate static SPICE port
port_file="$VMS_ROOT/env/next_spice_port"
spice_port=$(cat "$port_file" 2>/dev/null || echo 5900)
echo $((spice_port + 1)) > "$port_file"

info "Forking '$source' to '$name' (SPICE port $spice_port)"

# Create package cache directory
sudo mkdir -p "$pkg_dir"

# Create CoW clone using backing file
step "Creating disk (backing file)" \
    qemu-img create -f qcow2 -b "$source_disk" -F qcow2 "$disk"

# Clone VM definition
step "Cloning VM definition" \
    virt-clone \
    --original "$source" \
    --name "$name" \
    --preserve-data \
    --file "$disk"

# Set static SPICE port
set_spice_port() {
    virsh dumpxml "$name" | \
        sed "s/<graphics type='spice'[^>]*/<graphics type='spice' port='$spice_port' autoport='no' listen='127.0.0.1'/" | \
        virsh define /dev/stdin
}
step "Setting SPICE port $spice_port" set_spice_port

# Create viewer config
mkdir -p "$VMS_ROOT/env/vv"
sed "s/{{PORT}}/$spice_port/" "$VMS_ROOT/templates/viewer.vv" > "$VMS_ROOT/env/vv/$name.vv"

info "VM '$name' ready"
