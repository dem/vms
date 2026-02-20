# Console-Based Automated Installation - Summary

## Problem
Standard Arch Linux ISO does not provide serial console by default. Manual intervention was required at boot time to press 'e' and add `console=tty0 console=ttyS0,115200n8` to kernel parameters, which doesn't work for automated installations.

## Solution
Use **direct kernel boot** with virt-install, bypassing the ISO's bootloader entirely and passing console parameters directly to the kernel.

## Key Components

### 1. VM Creation (`commands/create.sh`)
- Extracts kernel and initrd from Arch ISO
- Uses `--boot kernel=...,initrd=...,kernel_args=...` with console parameters
- Adds `--serial pty` for serial console access

```bash
virt-install \
    --boot "kernel=$kernel,initrd=$initrd,kernel_args=archisobasedir=arch archisosearchuuid=$iso_uuid console=tty0 console=ttyS0,115200n8" \
    --serial pty \
    ...
```

### 2. Console Automation (`lib/console.sh`)
Generic tool for VM interaction via virsh console using expect.

```bash
console.sh send <vm> <local-file> <remote-path>   # upload file
console.sh get <vm> <remote-path> <local-file>    # download file
console.sh run <vm> "command"                      # run command
console.sh exec <vm> <script> [args...]            # send + run script
```

Features:
- Uses `expect` to automate interaction with virsh console
- Base64 encodes files for transfer
- Sets `TERM=dumb` to disable colored prompts for reliable parsing
- Wraps commands with markers to detect success/failure
- Guest scripts don't need marker knowledge - just exit 0/1

#### Marker Design

Commands are wrapped with completion markers:
```bash
command && echo '__CONSOLE_DONE_1234__' || echo '__CONSOLE_FAIL_1234__'
```

**Problem: Command echo false match**

When a command is sent to the console, the shell echoes it back before executing:
```
READY# command && echo '__CONSOLE_DONE_1234__'
```
Expect would match the marker in the echo, not in the actual output.

**Solution: Newline prefix**

Match markers only when preceded by a newline:
```tcl
expect {
    "\n$marker_done" { success }
    "\n$marker_fail" { failure }
}
```
The echoed command line has no newline before the marker. The actual output does.

**PID-based uniqueness**

Markers include the shell PID (`$$`):
```bash
DONE_MARKER="__CONSOLE_DONE_$$__"  # e.g., __CONSOLE_DONE_12345__
```

Benefits:
- Prevents matching stale markers from previous sessions
- Avoids collision if script output accidentally contains marker-like text
- Aids debugging - each invocation has unique markers

### 3. Installation Script (`guest/install.sh`)
- Partitions disk (GPT with EFI partition)
- Installs base system via pacstrap
- Configures locale, timezone, hostname
- Sets up users with hashed passwords
- Installs systemd-boot bootloader with serial console parameters
- Enables serial-getty service for post-install console access

## Issues Encountered & Fixes

| Issue | Fix |
|-------|-----|
| Colored prompts breaking expect | Set `TERM=dumb PS1='READY# '` |
| Completion marker matched during heredoc transmission | Base64 encode the script |
| Marker matched in command echo before execution | Require newline prefix when matching (`\n$marker`) |
| Interactive pacman prompts | Use `pacstrap -K` with explicit packages including `mkinitcpio` |
| Line continuation backslashes garbled | Put packages on single line |
| mkinitcpio vconsole.conf warning | Add `echo "KEYMAP=us" > /etc/vconsole.conf` |
| VM not booting installed system | Add UEFI firmware (OVMF) to VM definition |

## Usage

```bash
# Create VM (boots Arch ISO with serial console)
./vms create myvm

# Wait ~30s for boot, then run automated install
root_hash=$(openssl passwd -6 'password')
user_hash=$(openssl passwd -6 'password')
./lib/console.sh exec myvm guest/install.sh myhostname myuser "$root_hash" "$user_hash"

# After install, need to reconfigure VM for UEFI boot from disk
# (TODO: automate this in vms tool)
```

## TODO
- Add UEFI firmware to VM creation by default
- Create `vms install` command to wrap console.sh exec
- Add more packages to base install (hostname, iproute2, etc.)
- Handle installation errors gracefully

## Files
- `lib/console.sh` - expect-based console automation (send/get/run/exec)
- `guest/install.sh` - installation script
- `commands/create.sh` - VM creation with direct kernel boot
