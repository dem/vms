# vms destroy <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms destroy <name>"

info "Destroying VM '$name'"
echo "[TODO] virsh destroy $name (if running)"
echo "[TODO] virsh undefine $name --nvram"
echo "[TODO] rm $VMS_IMAGES/$name.qcow2"
info "VM '$name' removed."
