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
