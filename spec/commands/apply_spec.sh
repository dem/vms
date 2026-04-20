Describe "vms apply"
  Include lib/common.sh

  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "myvm" ]] && return 0
        return 1
        ;;
      domstate)
        echo "${_vm_state:-running}"
        ;;
      start|shutdown|destroy)
        echo "$1 $2"
        return 0
        ;;
    esac
  }

  virt-xml() {
    echo "virt-xml $*"
    return 0
  }

  setup() {
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/lib" "$VMS_ROOT/guest/profiles" "$VMS_ROOT/env"
    echo "testuser" > "$VMS_ROOT/env/user"
    touch "$VMS_ROOT/guest/profiles/gui.sh"
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
stop_vm() { return 0; }
wait_for_boot() { return 0; }
STUB
    cat > "$VMS_ROOT/lib/console.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$VMS_ROOT/lib/console.sh"
  }

  cleanup() {
    rm -rf "$VMS_ROOT"
  }

  BeforeEach setup
  AfterEach cleanup

  It "fails without arguments"
    When run source commands/apply.sh
    The status should eq 1
    The stderr should include "usage: vms apply"
  End

  It "fails with only VM name and no flags"
    _vm_state="running"
    When run source commands/apply.sh "myvm"
    The status should eq 1
    The stderr should include "nothing to apply"
  End

  It "rejects invalid VM name"
    When run source commands/apply.sh "bad name" "gui"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "fails when VM does not exist"
    When run source commands/apply.sh "novm" "gui"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "fails when profile does not exist"
    When run source commands/apply.sh "myvm" "nosuch"
    The status should eq 1
    The stderr should include "Profile nosuch not found"
  End

  It "fails when env/user is empty"
    rm -f "$VMS_ROOT/env/user"
    touch "$VMS_ROOT/env/user"
    _vm_state="running"
    When run source commands/apply.sh "myvm" "gui"
    The status should eq 1
    The stderr should include "env/user not set"
  End

  It "rejects transitional states"
    _vm_state="paused"
    When run source commands/apply.sh "myvm" "gui"
    The status should eq 1
    The stderr should include "stop or start"
  End

  It "rejects unknown option"
    _vm_state="running"
    When run source commands/apply.sh "myvm" --bogus value
    The status should eq 1
    The stderr should include "unknown option"
  End

  It "applies profile and restarts when VM was running"
    _vm_state="running"
    When run source commands/apply.sh "myvm" "gui"
    The status should eq 0
    The output should include "Applying profile gui"
    The output should include "Restarting VM"
    The output should include "Applied to myvm"
  End

  It "starts, applies, stops when VM was shut off"
    _vm_state="shut off"
    When run source commands/apply.sh "myvm" "gui"
    The status should eq 0
    The output should include "Starting VM"
    The output should include "Applying profile gui"
    The output should include "Stopping VM"
    The output should not include "Restarting VM"
    The output should include "Applied to myvm"
  End

  Describe "HW changes"
    It "changes memory only, no profile"
      _vm_state="shut off"
      When run source commands/apply.sh "myvm" --memory 4G
      The status should eq 0
      The output should include "Setting memory to 4G (4096 MB)"
      The output should not include "Applying profile"
      The output should include "Applied to myvm"
    End

    It "changes cpus on running VM, restores running state"
      _vm_state="running"
      When run source commands/apply.sh "myvm" --cpus 4
      The status should eq 0
      The output should include "Stopping VM"
      The output should include "Setting CPUs to 4"
      The output should include "Starting VM"
    End

    It "changes displays"
      _vm_state="shut off"
      When run source commands/apply.sh "myvm" --displays 2
      The status should eq 0
      The output should include "Setting displays to 2"
    End

    It "combines HW change and profile"
      _vm_state="running"
      When run source commands/apply.sh "myvm" "gui" --memory 4G
      The status should eq 0
      The output should include "Stopping VM"
      The output should include "Setting memory to 4G (4096 MB)"
      The output should include "Applying profile gui"
      The output should include "Restarting VM"
    End
  End
End
