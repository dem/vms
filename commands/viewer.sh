# vms viewer <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms viewer <name>"

info "Opening viewer for '$name'"
echo "[TODO] virt-viewer $name"
