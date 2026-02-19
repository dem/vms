# VMS CLI Design

Single entry point script for all VM operations.

## Usage Flow

```
# 1. Clone repo on fresh Arch install
git clone https://github.com/dem/vms.git
cd vms

# 2. Bootstrap host
./vms bootstrap

# 3. Create a VM
./vms create work --profile gui

# 4. Connect
./vms console work    # serial console as root
./vms viewer work     # SPICE UI with app running
```

## Commands

| Command                         | Description                                   |
|---------------------------------|-----------------------------------------------|
| `vms bootstrap`                 | Install host dependencies (libvirt, qemu)     |
| `vms create <name> [--profile]` | Create new VM from scratch                    |
| `vms clone <source> <name>`     | Clone existing VM (qcow2 backing file)        |
| `vms start <name>`              | Start VM                                      |
| `vms stop <name>`               | Stop VM (graceful shutdown)                   |
| `vms kill <name>`               | Force stop VM                                 |
| `vms console <name>`            | Attach to serial console (root)               |
| `vms viewer <name>`             | Open SPICE viewer (GUI with app)              |
| `vms list`                      | List all VMs with status                      |
| `vms destroy <name>`            | Remove VM and its storage                     |

## Profiles

Profiles define what gets installed and what app runs on login.

| Profile   | Base | Desktop | Default App | Use Case            |
|-----------|------|---------|-------------|---------------------|
| `minimal` | base | none    | shell       | Headless, servers   |
| `gui`     | base | i3+X11  | none        | General GUI work    |
| `browser` | base | i3+X11  | chromium    | Web browsing        |
| `telegram`| base | i3+X11  | telegram    | Messaging           |
| `dev`     | base | i3+X11  | terminal    | Development env     |

## Script Structure

```
vms                     # Main entry point (bash)
├── commands/
│   ├── bootstrap.sh
│   ├── create.sh
│   ├── clone.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── console.sh
│   ├── viewer.sh
│   ├── list.sh
│   └── destroy.sh
├── lib/
│   ├── common.sh
│   ├── config.sh
│   └── console-install.sh
├── guest/                  # scripts that run inside VM
│   ├── install.sh
│   └── profiles/
│       ├── minimal.sh
│       ├── gui.sh
│       ├── browser.sh
│       ├── telegram.sh
│       └── dev.sh
└── templates/
    └── domain.xml
```

## Main Script (`vms`)

```bash
#!/bin/bash
set -euo pipefail

VMS_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$VMS_ROOT/lib/common.sh"
source "$VMS_ROOT/lib/config.sh"

cmd="${1:-help}"
shift || true

case "$cmd" in
    bootstrap) source "$VMS_ROOT/commands/bootstrap.sh" "$@" ;;
    create)    source "$VMS_ROOT/commands/create.sh" "$@" ;;
    clone)     source "$VMS_ROOT/commands/clone.sh" "$@" ;;
    start)     source "$VMS_ROOT/commands/start.sh" "$@" ;;
    stop)      source "$VMS_ROOT/commands/stop.sh" "$@" ;;
    kill)      source "$VMS_ROOT/commands/kill.sh" "$@" ;;
    console)   source "$VMS_ROOT/commands/console.sh" "$@" ;;
    viewer)    source "$VMS_ROOT/commands/viewer.sh" "$@" ;;
    list)      source "$VMS_ROOT/commands/list.sh" "$@" ;;
    destroy)   source "$VMS_ROOT/commands/destroy.sh" "$@" ;;
    help|*)    usage ;;
esac
```

## Bootstrap Steps

```bash
# 1. Install packages
sudo pacman -S --needed \
    qemu-desktop \
    libvirt \
    virt-install \
    virt-viewer \
    dnsmasq \
    edk2-ovmf

# 2. Enable services
sudo systemctl enable --now libvirtd

# 3. Add user to libvirt group
sudo usermod -aG libvirt "$USER"

# 4. Create directories
sudo mkdir -p /var/lib/libvirt/{images,iso,filesystems/pkg/shared}
```

## Create Flow

```
vms create work --profile browser
    │
    ├── 1. Generate VM name and paths
    ├── 2. Create qcow2 disk image
    ├── 3. Generate domain XML from template
    ├── 4. Define VM in libvirt
    ├── 5. Start VM with ISO attached
    ├── 6. Run arch-install.sh inside VM
    ├── 7. Reboot into installed system
    ├── 8. Run profile setup (browser.sh)
    └── 9. VM ready
```

## Clone Flow

```
vms clone work work2
    │
    ├── 1. Create new qcow2 with backing file
    │      qemu-img create -f qcow2 -b work.qcow2 work2.qcow2
    ├── 2. Copy and modify domain XML
    │      - New name, UUID, MAC address
    ├── 3. Define new VM
    └── 4. Done (instant, minimal disk usage)
```

## Config (`lib/config.sh`)

```bash
# Paths
VMS_IMAGES="/var/lib/libvirt/images"
VMS_ISO="/var/lib/libvirt/iso"
VMS_FILESYSTEMS="/var/lib/libvirt/filesystems"
VMS_PKG_CACHE="/var/cache/pacman/pkg"

# Defaults
VMS_DEFAULT_MEMORY="2048"
VMS_DEFAULT_CPUS="2"
VMS_DEFAULT_DISK="20G"
VMS_DEFAULT_PROFILE="gui"

# Arch ISO
VMS_ARCH_ISO="$VMS_ISO/archlinux-x86_64.iso"
```

## Example Session

```bash
$ git clone https://github.com/dem/vms.git && cd vms

$ ./vms bootstrap
Installing packages... done
Enabling libvirtd... done
Bootstrap complete.

$ ./vms create work --profile dev
Creating disk... done
Installing Arch... done
Applying profile 'dev'... done
VM 'work' ready.

$ ./vms list
NAME   STATE    PROFILE
work   running  dev

$ ./vms viewer work
# Opens SPICE viewer

$ ./vms clone work test
Cloning... done

$ ./vms console work
Connected to domain 'work'
work login: root
[root@work ~]#
```
