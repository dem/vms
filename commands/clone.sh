# vms clone <source> <name>

source="${1:-}"
name="${2:-}"

[[ -z "$source" || -z "$name" ]] && die "usage: vms clone <source> <name>"

info "Cloning '$source' to '$name'"
echo "[TODO] qemu-img create -f qcow2 -b $VMS_IMAGES/$source.qcow2 -F qcow2 $VMS_IMAGES/$name.qcow2"
echo "[TODO] virsh dumpxml $source > /tmp/$name.xml"
echo "[TODO] modify XML (name, uuid, mac)"
echo "[TODO] virsh define /tmp/$name.xml"
info "VM '$name' ready."
