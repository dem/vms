# vms start <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms start <name>"

info "Starting VM '$name'"
echo "[TODO] virsh start $name"
