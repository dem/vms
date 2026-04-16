# vms stop <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms stop <name>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

source "$VMS_ROOT/lib/vm.sh"

state=$(virsh domstate "$name" 2>/dev/null)
case "$state" in
    "shut off")
        die "VM $name is not running"
        ;;
    "running"|"idle")
        step "Stopping VM $name" stop_vm "$name"
        ;;
    "in shutdown")
        step "Waiting for VM $name to shut down" stop_vm "$name"
        ;;
    "paused"|"crashed"|"pmsuspended")
        step "Force stopping VM $name" virsh destroy "$name"
        ;;
    *)
        die "VM $name is in unexpected state: $state"
        ;;
esac
