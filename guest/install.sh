#!/bin/bash
set -e

# Arch Linux Automated Installation Script for VMs
# Usage: ./arch-install.sh <hostname> <username> <root_hash> <user_hash> [uid] [gid] [noautologin]

DISK="/dev/vda"
HOSTNAME="${1:?hostname required}"
USERNAME="${2:?username required}"
ROOT_HASH="${3:?root_hash required}"
USER_HASH="${4:?user_hash required}"
USER_UID="${5:-}"
USER_GID="${6:-}"
NOAUTOLOGIN="${7:-}"

echo "Target disk: $DISK"
echo "Hostname: $HOSTNAME"
echo "Username: $USERNAME"

# Verify we're in the live environment
if [ ! -f /etc/arch-release ]; then
    echo "Error: This script must be run from Arch Linux live environment"
    exit 1
fi

# 1. Partition the disk
echo "=== Partitioning disk ==="
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

# Wait for kernel to recognize partitions
echo "Waiting for partitions..."
for i in {1..10}; do
    if [ -e "${DISK}1" ] && [ -e "${DISK}2" ]; then
        echo "Partitions detected"
        break
    fi
    sleep 1
done

if [ ! -e "${DISK}1" ] || [ ! -e "${DISK}2" ]; then
    echo "Error: Partitions not detected"
    exit 1
fi

# 2. Format partitions
echo "=== Formatting partitions ==="
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

# 3. Mount filesystems
echo "=== Mounting filesystems ==="
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# Create mount points for shared cache
mkdir -p /mnt/var/cache/pacman/pkg-host
mkdir -p /mnt/var/cache/pacman/pkg

# Try to mount virtiofs shares
mount -t virtiofs pkg-host /mnt/var/cache/pacman/pkg-host 2>/dev/null || true
mount -t virtiofs pkg /mnt/var/cache/pacman/pkg 2>/dev/null || true

# Mount guest scripts into target for chroot access
mkdir -p /mnt/vms
mount -t virtiofs vms /mnt/vms 2>/dev/null || true

# 4. Install base system
echo "=== Installing packages ==="
cp /etc/pacman.conf /tmp/pacman-vm.conf
sed -i '/^\[options\]/a CacheDir = /mnt/var/cache/pacman/pkg/\nCacheDir = /mnt/var/cache/pacman/pkg-host/' /tmp/pacman-vm.conf
pacstrap -K -C /tmp/pacman-vm.conf /mnt base linux mkinitcpio networkmanager sudo vi less

# 5. Generate fstab
echo "=== Generating fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

# Add virtiofs mounts
echo "" >> /mnt/etc/fstab
echo "# Shared pacman cache via virtiofs" >> /mnt/etc/fstab
echo "pkg-host  /var/cache/pacman/pkg-host  virtiofs  ro,nofail  0 0" >> /mnt/etc/fstab
echo "pkg       /var/cache/pacman/pkg       virtiofs  defaults,nofail  0 0" >> /mnt/etc/fstab
echo "vms       /vms                        virtiofs  ro,nofail        0 0" >> /mnt/etc/fstab

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value "${DISK}2")

# 6. Configure the system
echo "=== Configuring system ==="
arch-chroot /mnt /bin/bash <<CHROOT_EOF
set -e

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Console settings (needed for mkinitcpio)
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Set root password
usermod -p '$ROOT_HASH' root

# Create user
groupadd ${USER_GID:+-g $USER_GID} "$USERNAME"
useradd -m -g "$USERNAME" ${USER_UID:+-u $USER_UID} -s /bin/bash "$USERNAME"
usermod -p '$USER_HASH' "$USERNAME"
usermod -aG wheel "$USERNAME"

# Sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Serial console
systemctl enable serial-getty@ttyS0.service

# Bootloader
bootctl install
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 0
console-mode max
editor no
EOF

mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf <<EOF
title   $HOSTNAME
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw console=tty0 console=ttyS0,115200n8
EOF

# Network
systemctl enable NetworkManager

# Pacman cache
sed -i '/^\[options\]/a CacheDir = /var/cache/pacman/pkg/\nCacheDir = /var/cache/pacman/pkg-host/' /etc/pacman.conf

# Guest scripts mount point
mkdir -p /vms

CHROOT_EOF

# Autologin configuration
if [[ -z "$NOAUTOLOGIN" ]]; then
    echo "=== Configuring autologin ==="
    arch-chroot /mnt /vms/autologin.sh on root
    arch-chroot /mnt /vms/autologin.sh on user
fi

# 7. Finalize
umount -R /mnt
echo "=== Installation Complete ==="
