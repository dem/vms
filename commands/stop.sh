# vms stop <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms stop <name>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

state=$(virsh domstate "$name" 2>/dev/null)
if [[ "$state" != "running" ]]; then
    die "VM $name is not running"
fi

step "Stopping VM $name" virsh shutdown "$name"
