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
./vms create work gui

# 4. Connect
./vms console work    # serial console as root
./vms viewer work     # SPICE UI with app running
```

## VM Names

Names must match `[a-zA-Z0-9._-]+` — letters, numbers, hyphens, underscores, dots.

## Commands

| Command                         | Description                                   |
|---------------------------------|-----------------------------------------------|
| `vms bootstrap`                 | Install host dependencies (libvirt, qemu)     |
| `vms create <name> [profile]`   | Create new VM, optionally with profile        |
| `vms apply <name> [profile]`    | Apply a profile and/or HW changes to a VM     |
| `vms clone <source> <name>`     | Full copy of existing VM                      |
| `vms fork <source> <name>`      | Linked copy of existing VM (CoW backing file) |
| `vms start <name>`              | Start VM                                      |
| `vms stop <name>`               | Stop VM (graceful shutdown)                   |
| `vms kill <name>`               | Force stop VM                                 |
| `vms console <name>`            | Attach to serial console (root)               |
| `vms viewer <name>`             | Open SPICE viewer (GUI with app)              |
| `vms list`                      | List all VMs with status                      |
| `vms destroy <name>`            | Remove VM and its storage                     |
| `vms mount <name> <host> <guest>` | Mount host directory into guest via virtiofs |
| `vms umount <name> <guest>`    | Unmount a previously mounted directory        |

All commands accept `-v` / `--verbose` for detailed output.

## Shared mounts

Mount host directories into a guest VM via virtiofs.

```
vms mount myvm ~/projects /home/user/projects
vms mount myvm ~/data /mnt/data --readonly
vms mount myvm ~/tmp /mnt/tmp --temp
vms umount myvm /home/user/projects
```

### Modes

| Mode | VM state | Survives reboot | How it works |
|------|----------|-----------------|--------------|
| persistent (default) | stopped | yes | add virtiofs to domain XML + fstab entry inside guest |
| `--temp` | running | no | hotplug virtiofs to domain XML + mount inside guest |

### Flags

- `--readonly` — mount as read-only
- `--temp` — temporary mount on a running VM, lost on reboot
- `--force` — proceed even if guest directory contains files (see shadow warning)

### Tag naming

Each virtiofs share needs an internal tag linking the host XML entry to the guest
mount. Tags are derived from the guest mountpoint: `/home/user/projects` →
`home-user-projects`. On conflict, a numeric suffix is appended (`-1`, `-2`, etc.).

### Shadow warning

If the guest mountpoint already exists and contains files, the mount will shadow
them (files still exist on disk but are hidden). `vms mount` refuses in this case
and requires `--force` to proceed:

```
error: /home/user/projects exists and contains files — mount will shadow them
use --force to proceed
```

### Unmount

`vms umount` auto-detects whether the mount is persistent or temporary and
reverses accordingly — removes fstab entry + XML device (persistent) or
unmounts + detaches (temporary).

## Profiles

Profiles add packages and configuration on top of the base system. No profile = base system only.

| Profile   | Desktop | Default App | Use Case            |
|-----------|---------|-------------|---------------------|
| `gui`     | i3+X11  | none        | General GUI work    |
| `browser` | i3+X11  | chromium    | Web browsing        |
| `telegram`| i3+X11  | telegram    | Messaging           |
| `dev`     | i3+X11  | alacritty   | Development env     |

Profiles are hierarchical — each script calls its dependency if needed:

```
base (no profile)
└── gui (i3, X11, spice-vdagent)
    ├── browser (gui + chromium)
    ├── telegram (gui + telegram)
    └── dev (gui + dev tools + claude code)
```

### Applying profiles to an existing VM

A profile can be applied either at creation time as the second positional
argument, or afterwards via `vms apply <vm> <profile>`. The VM can be
running or stopped:

- **Running**: applies the profile, then restarts the VM to pick up session
  changes (e.g. `.bash_profile` updates).
- **Stopped**: starts the VM, applies the profile, stops it again. Final
  state matches the initial state.

```
vms create myvm dev                 # installs gui + dev
vms apply myvm telegram              # adds telegram on top; gui is skipped
```

### Hardware configuration

Both `create` and `apply` accept the same flags for adjusting VM hardware:

| Flag | Description |
|------|-------------|
| `--memory <size>` | VM memory; requires `G` or `M` suffix (e.g. `4G`, `512M`) |
| `--cpus <N>` | Number of virtual CPUs |
| `--displays <N>` | Number of display heads (1 or 2) |

`apply` can combine HW changes with a profile, or change just hardware (no
profile argument needed). At least one of profile/flags must be given. HW
changes require the VM to be stopped — `apply` stops it transparently,
edits the domain XML, then restores the initial state.

```
vms create myvm dev --memory 4G --cpus 4 --displays 2
vms apply myvm --memory 8G             # HW only, no profile
vms apply myvm browser --displays 2    # profile + HW change
```

### Idempotency and marker files

Each profile script writes a marker file `/etc/vms-profiles/<name>` after
successful application and checks for it at the top. If present, the script
exits immediately. This makes profile chains safe to re-apply — when
`telegram.sh` delegates to `gui.sh`, `gui.sh` self-skips if already applied,
so only the telegram-specific steps run.

### Autostart ownership

`gui` sets alacritty as the i3 autostart app. A profile applied on top of
`gui` may want to replace it with its own app (e.g. telegram wants Telegram
to auto-start). The rule:

> The first non-gui profile applied claims the autostart slot. Subsequent
> profiles leave it alone.

Detection uses the same marker files: when a profile runs, it checks
`/etc/vms-profiles/` for any non-gui, non-self marker. If none → it's the
first → claim the slot. If another marker exists → another profile got here
first → skip.

| Scenario | Autostart |
|----------|-----------|
| `vms create foo gui` | alacritty |
| `vms create foo telegram` | Telegram (claims slot) |
| `vms create foo dev` | alacritty (dev's "relevant app" happens to be alacritty) |
| `vms create foo dev` → `vms apply foo telegram` | alacritty (dev already claimed) |
| `vms create foo telegram` → `vms apply foo dev` | Telegram (telegram already claimed) |

Users can always edit `~/.config/i3/config` manually to change the autostart.

### Profile layout

Each profile is a shell script under `guest/profiles/<name>.sh` containing the
install logic (packages, ownership, etc.). When a profile needs config files or
other assets, they go in a sibling directory `guest/profiles/<name>/` — any
layout is fine, the script just references them via `/vms/profiles/<name>/...`
(the `guest/` tree is mounted read-only inside the VM at `/vms`).

Convention for asset filenames:
- plain name = drop-in file (e.g. `i3-config`, `xinitrc`)
- `.append` suffix = appended to the target instead of overwriting (e.g. `bash_profile.append`)

### dev profile packages

Shell essentials: `bash-completion`, `man-db`, `man-pages`, `openssh`, `curl`, `wget`
Editors: `vim`, `neovim`, `meld` (merge conflicts)
Dev tools: `git`, `tmux`, `docker`, `base-devel`
Modern CLI: `ripgrep`, `fd`, `jq`, `yq`, `miller`, `htop`, `tree`, `bat`, `git-delta`, `glow`
AI: `claude code` (installed via official script)

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
│   └── console.sh
├── guest/                  # scripts that run inside VM
│   ├── install.sh
│   └── profiles/
│       ├── gui.sh          # logic: install pkgs, drop assets in place
│       ├── gui/            # sibling dir with config files, templates, etc.
│       │   ├── i3-config
│       │   ├── spice-autoresize.sh
│       │   ├── xinitrc
│       │   └── bash_profile.append
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
vms create work browser
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

$ ./vms create work dev
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
