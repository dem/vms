# vms stop <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms stop <name>"

info "Stopping VM '$name'"
echo "[TODO] virsh shutdown $name"
