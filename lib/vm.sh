print_dots() {
    while true; do
        printf "." >&3 2>/dev/null || printf "."
        sleep 1
    done
}

stop_dots() {
    kill "$1" 2>/dev/null
    wait "$1" 2>/dev/null
    printf "\n" >&3 2>/dev/null || echo ""
}

wait_for_console() {
    local vm="$1" i
    if [[ "$VMS_VERBOSE" != "1" ]]; then
        print_dots &
        local dots_pid=$!
    fi
    for i in $(seq 1 30); do
        if [[ "$VMS_VERBOSE" == "1" ]]; then
            if "$VMS_ROOT/lib/console.sh" run "$vm" "true"; then
                return 0
            fi
        else
            if "$VMS_ROOT/lib/console.sh" run "$vm" "true" &>/dev/null; then
                stop_dots "$dots_pid"
                return 0
            fi
        fi
        sleep 2
    done
    [[ "$VMS_VERBOSE" != "1" ]] && stop_dots "$dots_pid"
    die "Timed out waiting for console on '$vm'"
}

stop_vm() {
    local vm="$1"
    virsh shutdown "$vm"
    for i in $(seq 1 30); do
        if ! virsh domstate "$vm" 2>/dev/null | grep -q "running"; then
            return 0
        fi
        sleep 2
    done
    die "Timed out waiting for '$vm' to shut down"
}
