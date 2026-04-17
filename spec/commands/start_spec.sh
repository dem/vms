Describe "vms start"
  Include lib/common.sh

  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "myvm" ]] && return 0
        return 1
        ;;
      domstate)
        echo "${_vm_state:-shut off}"
        ;;
      start|resume|destroy)
        echo "$1 $2"
        return 0
        ;;
    esac
  }

  setup() {
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/lib"
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
stop_vm() { return 0; }
STUB
  }

  cleanup() {
    rm -rf "$VMS_ROOT"
  }

  BeforeEach setup
  AfterEach cleanup

  It "rejects invalid VM name"
    When run source commands/start.sh "bad name"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "fails without arguments"
    When run source commands/start.sh
    The status should eq 1
    The stderr should include "usage: vms start"
  End

  It "fails when VM does not exist"
    When run source commands/start.sh "novm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "fails when VM is already running"
    _vm_state="running"
    When run source commands/start.sh "myvm"
    The status should eq 1
    The stderr should include "already running"
  End

  It "starts a stopped VM"
    _vm_state="shut off"
    When run source commands/start.sh "myvm"
    The status should eq 0
    The output should include "Starting VM myvm"
  End

  It "resumes a paused VM"
    _vm_state="paused"
    When run source commands/start.sh "myvm"
    The status should eq 0
    The output should include "Resuming VM myvm"
  End

  It "recovers a crashed VM"
    _vm_state="crashed"
    When run source commands/start.sh "myvm"
    The status should eq 0
    The output should include "Starting VM myvm"
  End

  It "rejects in-shutdown VM after waiting fails"
    _vm_state="in shutdown"
    When run source commands/start.sh "myvm"
    The status should eq 0
    The output should include "Starting VM myvm"
  End
End
