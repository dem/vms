# vms console <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms console <name>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM '$name' does not exist"
fi

info "Connecting to console '$name' (Ctrl+] to exit)"
virsh console "$name"
