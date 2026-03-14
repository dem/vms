# vms kill <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms kill <name>"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM '$name' does not exist"
fi

info "Force stopping VM '$name'"
virsh destroy "$name" 2>/dev/null || true
