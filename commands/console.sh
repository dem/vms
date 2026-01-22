# vms console <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms console <name>"

info "Connecting to console '$name'"
echo "[TODO] virsh console $name"
