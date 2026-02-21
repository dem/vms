usage() {
    cat <<EOF
Usage: vms <command> [args]

Commands:
    bootstrap           Install host dependencies
    create <vm>         Create new VM
    clone <src> <vm>    Clone existing VM
    start <vm>          Start VM
    stop <vm>           Stop VM (graceful)
    kill <vm>           Force stop VM
    console <vm>        Serial console (root)
    viewer <vm>         SPICE viewer (GUI)
    list                List all VMs
    destroy <vm>        Remove VM and storage

Options:
    --profile <name>    Profile for create (default: gui)
    -v, --verbose       Show full command output
    --help              Show this help
EOF
    exit 1
}

VMS_VERBOSE=${VMS_VERBOSE:-0}

die() {
    echo "error: $1" >&2
    exit 1
}

info() { echo "$1"; }

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
