#!/bin/bash
# Usage: lib/iso.sh
# Ensures Arch ISO is present and fresh, extracts kernel/initrd
set -euo pipefail

VMS_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
source "$VMS_ROOT/lib/config.sh"
source "$VMS_ROOT/lib/common.sh"

kernel_dir="$VMS_ISO/arch-boot"
iso_url="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"

download_iso() {
    sudo curl -sL -o "$VMS_ARCH_ISO" "$iso_url" &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf "." >&3
        sleep 2
    done
    printf "\n" >&3
    wait "$pid"
}

extract_kernel() {
    sudo mkdir -p "$kernel_dir"
    tmp_mount=$(mktemp -d)
    sudo mount -o loop,ro "$VMS_ARCH_ISO" "$tmp_mount"
    sudo cp "$tmp_mount/arch/boot/x86_64/vmlinuz-linux" "$kernel_dir/vmlinuz-linux"
    sudo cp "$tmp_mount/arch/boot/x86_64/initramfs-linux.img" "$kernel_dir/initramfs-linux.img"
    sudo umount "$tmp_mount"
    rmdir "$tmp_mount"
}

if [[ ! -f "$VMS_ARCH_ISO" ]]; then
    step "Downloading Arch Linux ISO" download_iso
    step "Extracting kernel and initrd from ISO" extract_kernel
elif [[ -n "$(find "$VMS_ARCH_ISO" -mtime +30 2>/dev/null)" ]]; then
    step "Removing stale kernel/initrd" sudo rm -rf "$kernel_dir"
    step "Downloading Arch Linux ISO" download_iso
    step "Extracting kernel and initrd from ISO" extract_kernel
elif [[ ! -f "$kernel_dir/vmlinuz-linux" ]] || [[ ! -f "$kernel_dir/initramfs-linux.img" ]]; then
    step "Extracting kernel and initrd from ISO" extract_kernel
fi
