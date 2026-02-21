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

wait_for_boot() {
    local vm="$1" i
    if [[ "$VMS_VERBOSE" != "1" ]]; then
        print_dots &
        local dots_pid=$!
    fi
    for i in $(seq 1 60); do
        if expect "$VMS_ROOT/lib/console-wait.exp" "$vm" 2>/dev/null; then
            [[ "$VMS_VERBOSE" != "1" ]] && stop_dots "$dots_pid"
            return 0
        fi
        sleep 1
    done
    [[ "$VMS_VERBOSE" != "1" ]] && stop_dots "$dots_pid"
    die "Timed out waiting for '$vm' to boot"
}

wait_for_console() {
    local vm="$1"
    wait_for_boot "$vm"
    "$VMS_ROOT/lib/console.sh" run "$vm" "true" &>/dev/null \
        || die "Console on '$vm' not responding"
}

stop_vm() {
    local vm="$1"
    virsh shutdown "$vm"
    for i in $(seq 1 30); do
        if virsh domstate "$vm" 2>/dev/null | grep -q "shut off"; then
            return 0
        fi
        sleep 2
    done
    die "Timed out waiting for '$vm' to shut down"
}
