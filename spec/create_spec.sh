Describe "create helpers"
  Include lib/common.sh
  Include lib/vm.sh

  Describe "wait_for_console()"
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

    It "succeeds when console responds on first try"
      printf '#!/bin/bash\nexit 0\n' > "$mock_dir/lib/console.sh"
      chmod +x "$mock_dir/lib/console.sh"

      When call wait_for_console "testvm"
      The status should eq 0
    End

    It "succeeds when console responds after retries"
      cat > "$mock_dir/lib/console.sh" << 'EOF'
#!/bin/bash
counter_file="/tmp/shellspec_console_counter"
count=$(cat "$counter_file" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$counter_file"
[ "$count" -ge 3 ]
EOF
      chmod +x "$mock_dir/lib/console.sh"
      echo 0 > /tmp/shellspec_console_counter

      When call wait_for_console "testvm"
      The status should eq 0
    End

    It "fails after timeout when console never responds"
      printf '#!/bin/bash\nexit 1\n' > "$mock_dir/lib/console.sh"
      chmod +x "$mock_dir/lib/console.sh"

      When run wait_for_console "testvm"
      The status should eq 1
      The stderr should include "Timed out waiting for console on 'testvm'"
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
