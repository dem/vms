usage() {
    cat <<EOF
Usage: vms <command> [args]

Commands:
    bootstrap                 Install host dependencies
    create <vm> [profile]     Create new VM, optionally with profile
    apply <vm> [profile]      Apply a profile and/or HW changes to a VM
    clone <src> <vm>          Full copy VM
    fork <src> <vm>           Linked copy VM
    start <vm>                Start VM
    stop <vm>                 Graceful stop VM
    kill <vm>                 Force stop VM
    console <vm>              Serial console (root)
    viewer <vm>               GUI viewer (user)
    list                      List all VMs
    destroy <vm>              Remove VM and storage
    mount <vm> <from> <to>    Share host directory into guest
    umount <vm> <to>          Unmount shared directory

Create/apply options:
    --memory <size>           VM memory with G or M suffix (default: $VMS_DEFAULT_MEMORY)
    --cpus <N>                Number of vCPUs (default: $VMS_DEFAULT_CPUS)
    --displays <N>            Number of displays, 1 or 2 (default: $VMS_DEFAULT_DISPLAYS)

Create-only options:
    --disk <size>             Disk size with K/M/G/T suffix (default: $VMS_DEFAULT_DISK)
    --noautologin             Skip autologin setup

Mount options:
    --readonly                Mount as read-only
    --temp                    Temporary mount on running VM, lost on reboot
    --force                   Mount even if guest directory is non-empty

Global options:
    -v, --verbose             Show full command output
EOF
    exit 1
}

VMS_VERBOSE=${VMS_VERBOSE:-0}

validate_name() {
    [[ "$1" =~ ^[a-zA-Z0-9._-]+$ ]] || die "Invalid VM name '$1': use only letters, numbers, hyphens, underscores, dots"
}

# Convert a memory spec like "4G" or "512M" to megabytes (as expected by
# virt-install/virt-xml). Requires an explicit G or M suffix.
memory_to_mb() {
    case "$1" in
        *G|*g) echo "$(( ${1%[Gg]} * 1024 ))" ;;
        *M|*m) echo "${1%[Mm]}" ;;
        *) die "memory must have G or M suffix (e.g. 4G, 512M): $1" ;;
    esac
}

# parse_hw_flags — extract --memory, --cpus, --displays from args.
# Sets globals HW_MEMORY, HW_CPUS, HW_DISPLAYS (empty if not given) and
# HW_REMAINING (array of args that weren't HW flags). Callers then use
# `set -- "${HW_REMAINING[@]+"${HW_REMAINING[@]}"}"` to continue parsing.
parse_hw_flags() {
    HW_MEMORY=""
    HW_CPUS=""
    HW_DISPLAYS=""
    HW_REMAINING=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --memory) HW_MEMORY="$2"; shift 2 ;;
            --cpus) HW_CPUS="$2"; shift 2 ;;
            --displays) HW_DISPLAYS="$2"; shift 2 ;;
            *) HW_REMAINING+=("$1"); shift ;;
        esac
    done
}

allocate_spice_port() {
    local port_file="$VMS_ROOT/env/next_spice_port"
    (
        flock -x 9
        local port
        port=$(cat "$port_file" 2>/dev/null || echo 5900)
        echo $((port + 1)) > "$port_file"
        echo "$port"
    ) 9>"$port_file.lock"
}

die() {
    echo "error: $1" >&2
    exit 1
}

info() {
    if [[ "$VMS_VERBOSE" == "1" ]]; then
        echo "==> $1"
    else
        echo "$1"
    fi
}

step() {
    local msg="$1"; shift
    if [[ "$VMS_VERBOSE" == "1" ]]; then
        echo "==> $msg"
        "$@" 3>&1
    else
        echo "$msg"
        local output rc=0
        { output=$("$@" 3>&4 2>&1) || rc=$?; } 4>&1
        if [[ $rc -eq 0 ]]; then
            return 0
        else
            local reason
            reason=$(echo "$output" | grep -v '^$' | tail -1)
            echo "FAILED: ${reason:-$msg}" >&2
            echo "--- output ---" >&2
            echo "$output" >&2
            exit $rc
        fi
    fi
}
