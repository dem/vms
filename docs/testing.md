# Testing

Tests use [shellspec](https://shellspec.info/) ([GitHub](https://github.com/shellspec/shellspec)) — BDD framework for shell scripts.

## Install

```bash
sudo aura -A shellspec
```

## Run

```bash
shellspec
```

## Structure

```
spec/
  spec_helper.sh      # shared setup
  console_spec.sh     # console.sh tests
```

## Notes

- Tests require a running VM for integration tests
- Basic tests (argument validation, error paths) run without a VM
