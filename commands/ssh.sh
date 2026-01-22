# vms ssh <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms ssh <name>"

info "SSH to '$name'"
echo "[TODO] get VM IP from virsh domifaddr $name"
echo "[TODO] ssh user@<ip>"
