usage() {
    cat <<EOF
Usage: vms <command> [args]

Commands:
    bootstrap                 Install host dependencies
    create <vm>               Create new VM
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

Create options:
    --profile <name>          Install profile on top of base system
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
