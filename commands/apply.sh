# vms apply <vm> <profile>

name="${1:-}"
profile="${2:-}"
[[ -z "$name" || -z "$profile" ]] && die "usage: vms apply <vm> <profile>"
validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

profile_script="$VMS_ROOT/guest/profiles/$profile.sh"
[[ -f "$profile_script" ]] || die "Profile $profile not found"

vm_user="$(cat "$VMS_ROOT/env/user")"
[[ -z "$vm_user" ]] && die "env/user not set — run vms bootstrap"

source "$VMS_ROOT/lib/vm.sh"

state=$(virsh domstate "$name" 2>/dev/null)
was_running=0
case "$state" in
    running) was_running=1 ;;
    "shut off")
        step "Starting VM" virsh start "$name"
        step "Waiting for boot" wait_for_boot "$name"
        ;;
    *) die "VM $name is in state '$state' — stop or start it first" ;;
esac

apply_profile() {
    "$VMS_ROOT/lib/console.sh" run "$name" "/vms/profiles/$profile.sh '$vm_user'"
}
step "Applying profile $profile" apply_profile

if [[ "$was_running" == "1" ]]; then
    step "Restarting VM" stop_vm "$name"
    step "Starting VM" virsh start "$name"
    step "Waiting for boot" wait_for_boot "$name"
else
    step "Stopping VM" stop_vm "$name"
fi

info "Profile $profile applied to $name"
