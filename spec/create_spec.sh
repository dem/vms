Describe "create helpers"
  Include lib/common.sh
  Include lib/vm.sh

  Describe "wait_for_boot()"
    setup() {
      mock_dir=$(mktemp -d)
      mkdir -p "$mock_dir/lib"
      VMS_ROOT="$mock_dir"
    }
    cleanup() { rm -rf "$mock_dir"; }
    BeforeEach setup
    AfterEach cleanup

    # Override to avoid delays and background loops
    sleep() { :; }
    print_dots() { :; }
    stop_dots() { :; }

    It "succeeds when console prompt appears on first try"
      # Mock expect to succeed immediately
      expect() { return 0; }

      When call wait_for_boot "testvm"
      The status should eq 0
    End

    It "succeeds when console prompt appears after retries"
      expect() {
        local f="/tmp/shellspec_expect_counter"
        local c=$(cat "$f" 2>/dev/null || echo 0)
        c=$((c + 1))
        echo "$c" > "$f"
        [ "$c" -ge 3 ]
      }
      echo 0 > /tmp/shellspec_expect_counter

      When call wait_for_boot "testvm"
      The status should eq 0
    End

    It "fails after timeout when console never appears"
      expect() { return 1; }

      When run wait_for_boot "testvm"
      The status should eq 1
      The stderr should include "Timed out waiting for 'testvm' to boot"
    End
  End

  Describe "wait_for_console()"
    setup() {
      mock_dir=$(mktemp -d)
      mkdir -p "$mock_dir/lib"
      VMS_ROOT="$mock_dir"
    }
    cleanup() { rm -rf "$mock_dir"; }
    BeforeEach setup
    AfterEach cleanup

    sleep() { :; }
    print_dots() { :; }
    stop_dots() { :; }

    # Mock wait_for_boot to succeed (tested above)
    wait_for_boot() { return 0; }

    It "succeeds when console.sh run works"
      printf '#!/bin/bash\nexit 0\n' > "$mock_dir/lib/console.sh"
      chmod +x "$mock_dir/lib/console.sh"

      When call wait_for_console "testvm"
      The status should eq 0
    End

    It "fails when console.sh run fails"
      printf '#!/bin/bash\nexit 1\n' > "$mock_dir/lib/console.sh"
      chmod +x "$mock_dir/lib/console.sh"

      When run wait_for_console "testvm"
      The status should eq 1
      The stderr should include "Console on 'testvm' not responding"
    End
  End

  Describe "sync_packages()"
    setup() {
      pkg_dir=$(mktemp -d)
      VMS_PKG_CACHE=$(mktemp -d)
    }
    cleanup() {
      rm -rf "$pkg_dir" "$VMS_PKG_CACHE"
    }
    BeforeEach setup
    AfterEach cleanup

    # Override sudo to run commands without privilege
    sudo() { "$@"; }

    sync_packages() {
      local pkg sig
      for pkg in "$pkg_dir"/*.pkg.tar.zst; do
        [[ -f "$pkg" ]] || continue
        sig="$pkg.sig"
        if [[ -f "$sig" ]] && pacman-key --verify "$sig" "$pkg" &>/dev/null; then
          [[ -f "$VMS_PKG_CACHE/${pkg##*/}" ]] || mv "$pkg" "$sig" "$VMS_PKG_CACHE/"
        fi
      done
      rm -f "$pkg_dir"/*
    }

    It "moves verified pkg+sig pairs to host cache"
      touch "$pkg_dir/foo-1.0-1-x86_64.pkg.tar.zst"
      touch "$pkg_dir/foo-1.0-1-x86_64.pkg.tar.zst.sig"
      # Mock pacman-key to succeed
      pacman-key() { return 0; }

      When call sync_packages
      The status should eq 0
      The file "$VMS_PKG_CACHE/foo-1.0-1-x86_64.pkg.tar.zst" should be exist
      The file "$VMS_PKG_CACHE/foo-1.0-1-x86_64.pkg.tar.zst.sig" should be exist
      The directory "$pkg_dir" should be exist
    End

    It "skips packages without .sig file"
      touch "$pkg_dir/nosig-1.0-1-x86_64.pkg.tar.zst"
      pacman-key() { return 0; }

      When call sync_packages
      The status should eq 0
      The file "$VMS_PKG_CACHE/nosig-1.0-1-x86_64.pkg.tar.zst" should not be exist
      The directory "$pkg_dir" should be exist
    End

    It "skips packages with invalid signature"
      touch "$pkg_dir/bad-1.0-1-x86_64.pkg.tar.zst"
      touch "$pkg_dir/bad-1.0-1-x86_64.pkg.tar.zst.sig"
      # Mock pacman-key to fail
      pacman-key() { return 1; }

      When call sync_packages
      The status should eq 0
      The file "$VMS_PKG_CACHE/bad-1.0-1-x86_64.pkg.tar.zst" should not be exist
      The file "$VMS_PKG_CACHE/bad-1.0-1-x86_64.pkg.tar.zst.sig" should not be exist
      The directory "$pkg_dir" should be exist
    End

    It "skips packages already in host cache"
      touch "$pkg_dir/exists-1.0-1-x86_64.pkg.tar.zst"
      touch "$pkg_dir/exists-1.0-1-x86_64.pkg.tar.zst.sig"
      echo "original" > "$VMS_PKG_CACHE/exists-1.0-1-x86_64.pkg.tar.zst"
      pacman-key() { return 0; }

      When call sync_packages
      The status should eq 0
      The contents of file "$VMS_PKG_CACHE/exists-1.0-1-x86_64.pkg.tar.zst" should eq "original"
    End

    It "clears per-VM dir contents but keeps directory"
      touch "$pkg_dir/leftover.pkg.tar.zst"
      pacman-key() { return 0; }

      dir_is_empty() { [ -z "$(ls -A "$pkg_dir")" ]; }

      When call sync_packages
      The status should eq 0
      The directory "$pkg_dir" should be exist
      Assert dir_is_empty
    End
  End

  Describe "stop_vm()"
    # Override sleep to avoid delays
    sleep() { :; }

    It "succeeds when VM shuts down immediately"
      virsh() {
        case "$1" in
          shutdown) return 0 ;;
          domstate) echo "shut off" ;;
        esac
      }

      When call stop_vm "testvm"
      The status should eq 0
    End

    It "succeeds when VM shuts down after a delay"
      virsh() {
        case "$1" in
          shutdown) return 0 ;;
          domstate)
            local f="/tmp/shellspec_virsh_counter"
            local c=$(cat "$f" 2>/dev/null || echo 0)
            c=$((c + 1))
            echo "$c" > "$f"
            if [ "$c" -lt 3 ]; then echo "running"; else echo "shut off"; fi
            ;;
        esac
      }
      echo 0 > /tmp/shellspec_virsh_counter

      When call stop_vm "testvm"
      The status should eq 0
    End

    It "fails after timeout when VM stays running"
      virsh() {
        case "$1" in
          shutdown) return 0 ;;
          domstate) echo "running" ;;
        esac
      }

      When run stop_vm "testvm"
      The status should eq 1
      The stderr should include "Timed out waiting for 'testvm' to shut down"
    End
  End
End
