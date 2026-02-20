#!/bin/bash
# Automated installation via virsh console using expect
# Usage: console-install.sh <vm-name> <script-path> <hostname> <username> <root_hash> <user_hash>

set -euo pipefail

VM_NAME="$1"
SCRIPT_PATH="$2"
HOSTNAME="${3:-arch}"
USERNAME="${4:-user}"
ROOT_HASH="$5"
USER_HASH="$6"

# Check expect is installed
if ! command -v expect &>/dev/null; then
    echo "error: expect not installed. Run: sudo pacman -S expect" >&2
    exit 1
fi

# Generate the base64-encoded script payload
generate_payload() {
    local script_b64
    script_b64=$(base64 -w0 "$SCRIPT_PATH")
    echo "echo '$script_b64' | base64 -d > /root/install.sh"
    echo "chmod +x /root/install.sh"
    echo "/root/install.sh '$HOSTNAME' '$USERNAME' '$ROOT_HASH' '$USER_HASH'"
}

# Create expect script
EXPECT_SCRIPT=$(mktemp)
trap "rm -f $EXPECT_SCRIPT" EXIT

cat > "$EXPECT_SCRIPT" << 'EXPECT_EOF'
#!/usr/bin/expect -f

set timeout 900
set vm_name [lindex $argv 0]
set payload_file [lindex $argv 1]

# Read payload
set fp [open $payload_file r]
set payload [read $fp]
close $fp

log_user 1
fconfigure stdout -buffering none

puts "=== Connecting to console ==="
spawn virsh -c qemu:///system console $vm_name

# Wait for console connection
expect {
    "Escape character" {
        puts "=== Got escape character ==="
        sleep 2
        send "\r"
    }
    timeout {
        puts "Timeout waiting for console"
        exit 1
    }
}

# Wait for login prompt or shell
puts "=== Waiting for login/shell ==="
expect {
    -re "archiso login:" {
        puts "=== Got login prompt ==="
        sleep 1
        send "root\r"
        # Wait a bit for login to complete
        sleep 3
    }
    -re "#" {
        puts "=== Already at shell ==="
        sleep 1
    }
    timeout {
        puts "Timeout waiting for shell prompt"
        exit 1
    }
}

# Disable colors and get clean prompt - don't wait for old prompt
puts "=== Setting clean prompt ==="
send "export TERM=dumb PS1='READY# '\r"
sleep 1
send "\r"
expect {
    "READY#" {
        puts "=== Got clean prompt ==="
    }
    timeout {
        puts "=== Timeout waiting for READY# ==="
        exit 1
    }
}
sleep 1

# Send payload line by line (more reliable)
set lines [split $payload "\n"]
foreach line $lines {
    send "$line\r"
    sleep 0.05
}

# Wait for installation to complete - use unique marker that won't appear in heredoc transmission
expect {
    "INSTALL_FINISHED_MARKER_12345" {
        puts "=== Installation Complete ==="
        sleep 2
    }
    timeout {
        puts "Timeout waiting for installation to complete"
        exit 1
    }
}

# Exit console (Ctrl+])
send "\x1d"
expect eof
EXPECT_EOF

chmod +x "$EXPECT_SCRIPT"

# Generate payload and save to temp file
PAYLOAD_FILE=$(mktemp)
trap "rm -f $EXPECT_SCRIPT $PAYLOAD_FILE" EXIT
generate_payload > "$PAYLOAD_FILE"

# Run expect
expect "$EXPECT_SCRIPT" "$VM_NAME" "$PAYLOAD_FILE"
