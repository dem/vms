# vms create <name> [--profile <profile>]

name=""
profile="$VMS_DEFAULT_PROFILE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) profile="$2"; shift 2 ;;
        -*) die "unknown option: $1" ;;
        *) name="$1"; shift ;;
    esac
done

[[ -z "$name" ]] && die "usage: vms create <name> [--profile <profile>]"

info "Creating VM '$name' with profile '$profile'"
info "  disk: $VMS_IMAGES/$name.qcow2"
info "  memory: ${VMS_DEFAULT_MEMORY}MB"
info "  cpus: $VMS_DEFAULT_CPUS"
info "  iso: $VMS_ARCH_ISO"

echo ""
echo "[TODO] qemu-img create -f qcow2 $VMS_IMAGES/$name.qcow2 $VMS_DEFAULT_DISK"
echo "[TODO] generate domain XML from template"
echo "[TODO] virsh define domain.xml"
echo "[TODO] virsh start $name (boot from ISO)"
echo "[TODO] run arch-install.sh inside VM"
echo "[TODO] reboot VM"
echo "[TODO] run profile/$profile.sh inside VM"
echo ""
info "VM '$name' ready."
