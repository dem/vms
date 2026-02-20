#!/bin/bash
# VM console interaction via virsh console + expect
# Usage:
#   console.sh send <vm> <local-file> <remote-path>
#   console.sh get <vm> <remote-path> <local-file>
#   console.sh run <vm> "command"
#   console.sh exec <vm> <script> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Markers for command completion detection
DONE_MARKER="__CONSOLE_DONE_$$__"
FAIL_MARKER="__CONSOLE_FAIL_$$__"

die() { echo "error: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || die "file not found: $1"; }

check_expect() {
    command -v expect &>/dev/null || die "expect not installed. Run: sudo pacman -S expect"
}

# Run expect script with markers
run_expect() {
    local script="$1"; shift
    expect "$SCRIPT_DIR/$script" "$@" "$DONE_MARKER" "$FAIL_MARKER"
}

# Send file to VM
cmd_send() {
    local vm="$1"
    local local_file="$2"
    local remote_path="$3"

    require_file "$local_file"

    local b64
    b64=$(base64 -w0 "$local_file")

    local payload_file
    payload_file=$(mktemp)
    trap "rm -f '$payload_file'" EXIT

    cat > "$payload_file" << EOF
echo '$b64' | base64 -d > '$remote_path' && echo '$DONE_MARKER' || echo '$FAIL_MARKER'
EOF

    run_expect console-payload.exp "$vm" "$payload_file"
}

# Get file from VM
cmd_get() {
    local vm="$1"
    local remote_path="$2"
    local local_file="$3"

    local payload_file
    payload_file=$(mktemp)
    local output_file
    output_file=$(mktemp)
    trap "rm -f '$payload_file' '$output_file'" EXIT

    # Use markers to delimit the base64 content
    local start_marker="__START_FILE_CONTENT__"
    local end_marker="__END_FILE_CONTENT__"

    cat > "$payload_file" << EOF
if [ -f '$remote_path' ]; then
    echo '$start_marker'
    base64 -w0 '$remote_path'
    echo ''
    echo '$end_marker'
    echo '$DONE_MARKER'
else
    echo 'File not found: $remote_path' >&2
    echo '$FAIL_MARKER'
fi
EOF

    # Capture expect output
    run_expect console-payload.exp "$vm" "$payload_file" | tee "$output_file"

    # Extract base64 content between markers and decode
    # Strip all ANSI/control sequences, extract lines starting with markers
    sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' "$output_file" | \
        tr -d '\r' | \
        sed -n "/^${start_marker}$/,/^${end_marker}$/p" | \
        grep -v "^${start_marker}$" | grep -v "^${end_marker}$" | \
        base64 -d > "$local_file"

    echo "Saved to $local_file"
}

# Run command on VM (simple, no payload file)
cmd_run() {
    run_expect console-run.exp "$1" "$2"
}

# Send script and execute on VM
cmd_exec() {
    local vm="$1"
    local script="$2"
    shift 2
    local args=("$@")

    require_file "$script"

    local b64
    b64=$(base64 -w0 "$script")

    local remote_script="/tmp/console_exec_$$.sh"

    local payload_file
    payload_file=$(mktemp)
    trap "rm -f '$payload_file'" EXIT

    # Build args string with proper quoting
    local args_str=""
    for arg in "${args[@]}"; do
        args_str+=" '$arg'"
    done

    cat > "$payload_file" << EOF
echo '$b64' | base64 -d > '$remote_script'
chmod +x '$remote_script'
'$remote_script'$args_str && echo '$DONE_MARKER' || echo '$FAIL_MARKER'
rm -f '$remote_script'
EOF

    run_expect console-payload.exp "$vm" "$payload_file"
}

# Main
check_expect

cmd="${1:-}"
shift || true

case "$cmd" in
    send)
        [[ $# -ge 3 ]] || die "usage: console.sh send <vm> <local-file> <remote-path>"
        cmd_send "$1" "$2" "$3"
        ;;
    get)
        [[ $# -ge 3 ]] || die "usage: console.sh get <vm> <remote-path> <local-file>"
        cmd_get "$1" "$2" "$3"
        ;;
    run)
        [[ $# -ge 2 ]] || die "usage: console.sh run <vm> \"command\""
        cmd_run "$1" "$2"
        ;;
    exec)
        [[ $# -ge 2 ]] || die "usage: console.sh exec <vm> <script> [args...]"
        cmd_exec "$@"
        ;;
    *)
        echo "Usage:"
        echo "  console.sh send <vm> <local-file> <remote-path>"
        echo "  console.sh get <vm> <remote-path> <local-file>"
        echo "  console.sh run <vm> \"command\""
        echo "  console.sh exec <vm> <script> [args...]"
        exit 1
        ;;
esac
