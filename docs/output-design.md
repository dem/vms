# Block-based output system

## Context

All command output is dumped to terminal unfiltered. Want clean output where each step shows one plain text line, tool noise is hidden, but full output is dumped on failure. `-v` flag enables verbose mode.

## Output style

No prefix, plain text:
```
Extracting kernel and initrd from ISO
Creating disk image
Creating VM
VM 'myvm' started
```

On failure (error reason + full output of the failed step only):
```
Creating disk image
Creating VM
FAILED: qemu-img: Could not create 'myvm.qcow2': Permission denied
--- output ---
<full captured output of "Creating VM" step>
```
The FAILED line shows the last non-empty line from captured output (the actual error). Falls back to step name if output is empty. Previous successful steps' output stays hidden.

With `-v`: all output shown in real time, no buffering. Steps get `==>` prefix to stand out from tool output:
```
==> Creating disk image
Formatting 'myvm.qcow2', fmt=qcow2 size=21474836480
==> Creating VM
<virt-install output>
```

## Design

### `step` function in `lib/common.sh`

```bash
step() {
    local msg="$1"; shift
    if [[ "${VMS_VERBOSE:-0}" == "1" ]]; then
        echo "==> $msg"
        "$@"
    else
        echo "$msg"
        local output
        if output=$("$@" 2>&1); then
            return 0
        else
            local rc=$?
            local reason
            reason=$(echo "$output" | grep -v '^$' | tail -1)
            echo "FAILED: ${reason:-$msg}" >&2
            echo "$output" >&2
            exit $rc
        fi
    fi
}
```

### Flag parsing — flags at the end

Flags like `-v` come after positional args: `vms create myvm -v`

Each command script has a `while/case` arg parser. Add `-v` there:

```bash
case "$1" in
    --profile) profile="$2"; shift 2 ;;
    -v|--verbose) VMS_VERBOSE=1; shift ;;
    ...
esac
```

`VMS_VERBOSE` is checked by `step()` from `common.sh`. Default is `0`.

### `info()`

Thin wrapper, no prefix:

```bash
info() { echo "$1"; }
```

Use `info()` for plain messages (e.g., "VM 'myvm' started", final notes).
Use `step()` for messages that wrap a command whose output should be captured.

### Multi-command steps

Extract into inline functions:

```bash
setup_network() {
    sudo virsh net-destroy default 2>/dev/null || true
    sudo virsh net-undefine default 2>/dev/null || true
    # ...
    sudo virsh net-define /tmp/vms-default-net.xml
    sudo virsh net-start default
    sudo virsh net-autostart default
}
step "Setting up default network" setup_network
```

Functions share the shell scope (scripts are sourced), so they access all variables without passing args.

### Single command steps

```bash
step "Creating disk image" \
    qemu-img create -f qcow2 "$disk" "$VMS_DEFAULT_DISK"
```

## Files to modify

- `lib/common.sh` — add `step()`, change `info()` to drop `:: ` prefix, add `VMS_VERBOSE=0` default
- `commands/create.sh` — add `-v` to arg parser, replace `info` + bare command with `step` calls
- `commands/bootstrap.sh` — add `-v` to arg parser, replace `info` + bare command with `step` calls
