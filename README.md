# vms

Run your daily computing as a fleet of small Arch Linux VMs — one for work, one for banking, one for hobby projects, one for whatever you want to throw away tomorrow.

A small wrapper around libvirt/QEMU/KVM that makes both ends of the spectrum easy: long-lived VMs you keep around for years, and quick disposable ones you fork, poke at, and destroy. Inspired by Qubes, but simpler, hackable, and made of plain bash.

## Quick start

```sh
git clone https://github.com/dem/vms.git && cd vms
./vms bootstrap                  # one-time host setup
./vms create work dev            # fresh Arch VM with the dev profile
./vms viewer work                # SPICE window, ready to use
```

That's it. No YAML, no Ansible, no daemons of your own.

## What it gives you

- **Fast creation** — full Arch install from ISO, automated via the serial console.
- **Instant clones** — `vms fork src new` makes a copy-on-write VM in under a second.
- **Profiles** — `gui`, `browser`, `telegram`, `dev`. Stack them on top of any VM, any time.
- **Shared folders** — `vms mount myvm ~/projects /home/user/projects` exposes a host dir over virtiofs, with `--readonly` and `--temp` modes.
- **Shared package cache** — pacman downloads happen once on the host, every guest reads from it.
- **SPICE & serial** — graphical viewer for daily use, serial console for headless poking.
- **One bash script per command** — readable, debuggable, no framework to learn.

## A typical day

```sh
vms list                         # see what's running
vms fork dev scratch             # quick disposable copy of your dev VM
vms apply scratch --memory 8G    # bump RAM on the fly
vms viewer scratch               # poke at it
vms destroy scratch              # done
```

## Disposable VMs

Anything you don't want to keep, you `fork` from a trusted base, use, and `destroy`:

```sh
vms fork dev scratch             # copy-on-write, no real disk used yet
vms viewer scratch               # do the sketchy thing
vms destroy scratch              # gone, host untouched
```

Forks share their parent's disk via qcow2 backing files, so they're nearly free to create and only consume space for what you actually change. Pair this with a clean `gui` or `browser` template and you have a per-task throwaway environment in one second.

## Profiles

Profiles add packages and config on top of the base system. They're hierarchical, idempotent, and can be applied at create time or after the fact:

```sh
vms create chat telegram         # gui + telegram, autostarts Telegram
vms apply chat dev               # add dev tools later
```

| Profile   | What's in it                                         |
|-----------|------------------------------------------------------|
| `gui`     | i3 + X11 + spice-vdagent — minimal desktop           |
| `browser` | gui + chromium + firefox                             |
| `telegram`| gui + Telegram, set as the autostart app             |
| `dev`     | gui + git, neovim, tmux, docker, ripgrep, claude-code, … |

Adding your own profile is dropping a script into `guest/profiles/`.

## Requirements

- Arch Linux host (or an Arch derivative — Omarchy works)
- CPU with KVM, ~16 GB RAM if you want to run several VMs at once
- That's all the host needs — `vms bootstrap` installs the rest

Guests are Arch too, by design. One distro, one set of scripts, no abstractions.

## Status

Built for daily personal use. The CLI is stable, the internals are plain bash you can read in an afternoon. See `docs/goals.md` for the philosophy and `docs/cli-design.md` for the full command reference.
