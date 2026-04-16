# vms start <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms start <name>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

state=$(virsh domstate "$name" 2>/dev/null)
case "$state" in
    "running")
        die "VM $name is already running"
        ;;
    "shut off")
        step "Starting VM $name" virsh start "$name"
        ;;
    "paused")
        step "Resuming VM $name" virsh resume "$name"
        ;;
    "in shutdown")
        info "VM $name is shutting down, waiting..."
        source "$VMS_ROOT/lib/vm.sh"
        stop_vm "$name"
        step "Starting VM $name" virsh start "$name"
        ;;
    "crashed"|"pmsuspended")
        virsh destroy "$name" 2>/dev/null || true
        step "Starting VM $name" virsh start "$name"
        ;;
    *)
        die "VM $name is in unexpected state: $state"
        ;;
esac
