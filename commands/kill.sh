# vms kill <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms kill <name>"

info "Force stopping VM '$name'"
echo "[TODO] virsh destroy $name"
