usage() {
    cat <<EOF
Usage: vms <command> [args]

Commands:
    bootstrap           Install host dependencies
    create <name>       Create new VM
    clone <src> <name>  Clone existing VM
    start <name>        Start VM
    stop <name>         Stop VM (graceful)
    kill <name>         Force stop VM
    console <name>      Serial console (root)
    viewer <name>       SPICE viewer (GUI)
    list                List all VMs
    destroy <name>      Remove VM and storage
    ssh <name>          SSH into VM

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
