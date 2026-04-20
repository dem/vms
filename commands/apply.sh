# vms apply <vm> [profile] [--memory MB] [--cpus N] [--displays N]

parse_hw_flags "$@"
set -- "${HW_REMAINING[@]+"${HW_REMAINING[@]}"}"
memory="$HW_MEMORY"
cpus="$HW_CPUS"
displays="$HW_DISPLAYS"

positional=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -*) die "unknown option: $1" ;;
        *) positional+=("$1"); shift ;;
    esac
done

name="${positional[0]:-}"
profile="${positional[1]:-}"
[[ ${#positional[@]} -gt 2 ]] && \
    die "usage: vms apply <vm> [profile] [--memory MB] [--cpus N] [--displays N]"

[[ -z "$name" ]] && \
    die "usage: vms apply <vm> [profile] [--memory MB] [--cpus N] [--displays N]"

[[ -z "$profile$memory$cpus$displays" ]] && \
    die "nothing to apply — specify a profile and/or --memory/--cpus/--displays"

validate_name "$name"

if ! virsh dominfo "$name" &>/dev/null; then
    die "VM $name does not exist"
fi

if [[ -n "$profile" ]]; then
    profile_script="$VMS_ROOT/guest/profiles/$profile.sh"
    [[ -f "$profile_script" ]] || die "Profile $profile not found"

    vm_user="$(cat "$VMS_ROOT/env/user")"
    [[ -z "$vm_user" ]] && die "env/user not set — run vms bootstrap"
fi

source "$VMS_ROOT/lib/vm.sh"

state=$(virsh domstate "$name" 2>/dev/null)
was_running=0
case "$state" in
    running) was_running=1 ;;
    "shut off") ;;
    *) die "VM $name is in state '$state' — stop or start it first" ;;
esac

hw_change=0
[[ -n "$memory$cpus$displays" ]] && hw_change=1

# Track state ourselves — avoid re-querying virsh (and simplifies tests)
state_now="$state"

# 1. Stop VM if HW change needed (HW edits require stopped VM)
if [[ "$hw_change" == "1" && "$state_now" == "running" ]]; then
    step "Stopping VM" stop_vm "$name"
    state_now="shut off"
fi

# 2. Apply HW changes
if [[ -n "$memory" ]]; then
    memory_mb=$(memory_to_mb "$memory")
    # virt-xml --memory N only sets <currentMemory>; we also need the
    # <memory> maximum to actually change allocation for the stopped VM.
    step "Setting memory to $memory ($memory_mb MB)" \
        virt-xml "$name" --edit --memory "memory=$memory_mb,currentMemory=$memory_mb"
fi
[[ -n "$cpus" ]] && step "Setting CPUs to $cpus" \
    virt-xml "$name" --edit --vcpus "$cpus"
[[ -n "$displays" ]] && step "Setting displays to $displays" \
    virt-xml "$name" --edit --video "heads=$displays"

# 3. Apply profile (needs running VM)
if [[ -n "$profile" ]]; then
    if [[ "$state_now" != "running" ]]; then
        step "Starting VM" virsh start "$name"
        step "Waiting for boot" wait_for_boot "$name"
        state_now="running"
    fi

    apply_profile() {
        "$VMS_ROOT/lib/console.sh" run "$name" "/vms/profiles/$profile.sh '$vm_user'"
    }
    step "Applying profile $profile" apply_profile
fi

# 4. Reconcile final state
if [[ "$was_running" == "1" ]]; then
    if [[ "$state_now" != "running" ]]; then
        step "Starting VM" virsh start "$name"
        step "Waiting for boot" wait_for_boot "$name"
    elif [[ -n "$profile" ]]; then
        # Profile applied — restart to pick up session-level changes
        step "Restarting VM" stop_vm "$name"
        step "Starting VM" virsh start "$name"
        step "Waiting for boot" wait_for_boot "$name"
    fi
else
    if [[ "$state_now" == "running" ]]; then
        step "Stopping VM" stop_vm "$name"
    fi
fi

info "Applied to $name"
