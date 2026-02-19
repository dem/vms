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

### 2. Console Installation Script (`lib/console-install.sh`)
- Uses `expect` to automate interaction with virsh console
- Base64 encodes the install script to avoid marker matching issues
- Sets `TERM=dumb` to disable colored prompts for reliable parsing
- Uses unique completion marker: `INSTALL_FINISHED_MARKER_12345`

### 3. Installation Script (`install/arch-install.sh`)
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
./lib/console-install.sh myvm install/arch-install.sh myhostname myuser "$root_hash" "$user_hash"

# After install, need to reconfigure VM for UEFI boot from disk
# (TODO: automate this in vms tool)
```

## TODO
- Add UEFI firmware to VM creation by default
- Create `vms install` command to wrap console-install.sh
- Add more packages to base install (hostname, iproute2, etc.)
- Handle installation errors gracefully

## Files Modified
- `lib/console-install.sh` - expect-based console automation
- `install/arch-install.sh` - installation script
- `commands/create.sh` - VM creation with direct kernel boot
