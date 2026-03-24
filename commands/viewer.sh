# vms viewer <name>

name="${1:-}"
[[ -z "$name" ]] && die "usage: vms viewer <name>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

state=$(virsh domstate "$name" 2>/dev/null)
if [[ "$state" != "running" ]]; then
    die "VM $name is not running"
fi

vv_file="$VMS_ROOT/env/vv/$name.vv"
[[ -f "$vv_file" ]] || die "No viewer config for $name"

SPICE_NOGRAB=1 remote-viewer "$vv_file" &>/dev/null &
disown
