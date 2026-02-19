# VMS - High-Level Goals

A lightweight KVM/QEMU/libvirt VM management system for running isolated environments.
Inspired by QubesOS philosophy, but focused on simplicity and rapid deployment.

## Vision

Split daily computing into many small, isolated VMs:
- **Work** - separate VMs per client/project
- **Personal** - banking, email, social
- **Hobby** - development, gaming, experiments
- **Disposable** - quick throwaway environments

Each activity runs in its own VM. Easy to create, easy to destroy, easy to rebuild.

## Core Goals

### 1. Fast VM Creation and Cloning
- Create new VM from template in seconds
- Clone existing VMs instantly (qcow2 backing files)
- Disposable VMs that reset on shutdown
- Rebuild any environment from scratch quickly

### 2. Pure Bash, No Magic
- Everything is a bash script
- No complex frameworks or dependencies
- Easy to read, easy to modify, easy to debug
- Single set of scripts works for install and management

### 3. Opinionated: Arch Linux Only
- Host: Arch Linux (or derivatives like Omarchy)
- Guest: Arch Linux
- One distro = one set of scripts = simplicity
- Leverage pacman, systemd, and Arch conventions throughout

### 4. Reproducible Guest Structure
- Consistent guest layout across all VMs
- Defined installation steps (partition, base, bootloader, user)
- Shared pacman cache between host and guests
- Easy to customize and extend

### 5. Practical Daily Use
- SPICE for seamless graphics and clipboard
- USB device passthrough when needed
- Audio/video support
- Serial console for headless management

## Future Goals (Nice to Have)

- Network isolation between VM domains
- Controlled clipboard sharing
- Inter-VM communication protocol
- Firewall rules per VM type

## Non-Goals

- **Not cross-distro** - Arch only, by design
- **Not a Qubes replacement** - simpler, less secure
- **Not cross-platform** - Linux host only

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Host (Arch Linux)                    │
│  - libvirt/QEMU/KVM                                     │
│  - vms CLI (bash scripts)                               │
│  - shared pacman cache                                  │
└─────────────────────────────────────────────────────────┘
        │             │             │             │
   ┌────┴────┐   ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
   │  work   │   │  work   │   │ personal│   │  hobby  │
   │ client1 │   │ client2 │   │         │   │         │
   │         │   │         │   │ browser │   │   dev   │
   │ Arch VM │   │ Arch VM │   │ Arch VM │   │ Arch VM │
   └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

## VM Types

| Type       | Storage          | Persistence | Use Case                      |
|------------|------------------|-------------|-------------------------------|
| Template   | qcow2 base       | Read-only   | Base images (minimal, gui)    |
| AppVM      | qcow2            | Persistent  | Daily work VMs                |
| Disposable | qcow2 + backing  | Ephemeral   | Throwaway, resets on shutdown |

## Guest Structure

| Component     | Choice              | Reason                          |
|---------------|---------------------|---------------------------------|
| Distro        | Arch Linux          | Rolling, minimal, same as host  |
| Boot          | systemd-boot        | Simple, UEFI native             |
| Init          | systemd             | Standard, well supported        |
| Network       | NetworkManager      | Easy, works out of box          |
| Display       | X11 + i3            | Lightweight, scriptable         |
| Disk          | virtio (vda)        | Fast, standard for KVM          |
| Filesystem    | ext4                | Simple, reliable                |

## Directory Layout

```
/var/lib/libvirt/
├── images/              # VM disk images (.qcow2)
├── iso/                 # Arch ISO for installation
└── filesystems/pkg/     # Shared pacman cache
    ├── shared/          # Read-only, all VMs
    └── <vmname>/        # Per-VM packages
```

## Success Criteria

1. Create a new VM from template in <30 seconds
2. Full Arch install from scratch via single script
3. Clone existing VM in <10 seconds
4. All operations via bash scripts (no GUI required)
5. Run 5+ VMs on 16GB RAM comfortably
