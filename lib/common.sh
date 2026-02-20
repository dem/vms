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
    --help              Show this help
EOF
    exit 1
}

die() {
    echo "error: $1" >&2
    exit 1
}

info() {
    echo ":: $1"
}
