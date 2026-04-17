Describe "vms stop"
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
      shutdown|destroy)
        echo "$1 $2"
        return 0
        ;;
    esac
  }

  setup() {
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/lib"
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
stop_vm() { echo "stop_vm $1"; return 0; }
STUB
  }

  cleanup() {
    rm -rf "$VMS_ROOT"
  }

  BeforeEach setup
  AfterEach cleanup

  It "rejects invalid VM name"
    When run source commands/stop.sh "bad name"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "fails without arguments"
    When run source commands/stop.sh
    The status should eq 1
    The stderr should include "usage: vms stop"
  End

  It "fails when VM does not exist"
    When run source commands/stop.sh "novm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "fails when VM is already shut off"
    _vm_state="shut off"
    When run source commands/stop.sh "myvm"
    The status should eq 1
    The stderr should include "is not running"
  End

  It "shuts down a running VM"
    _vm_state="running"
    When run source commands/stop.sh "myvm"
    The status should eq 0
    The output should include "Stopping VM myvm"
  End

  It "waits for an in-shutdown VM"
    _vm_state="in shutdown"
    When run source commands/stop.sh "myvm"
    The status should eq 0
    The output should include "Waiting for VM myvm to shut down"
  End

  It "force-stops a paused VM"
    _vm_state="paused"
    When run source commands/stop.sh "myvm"
    The status should eq 0
    The output should include "Force stopping VM myvm"
  End

  It "force-stops a crashed VM"
    _vm_state="crashed"
    When run source commands/stop.sh "myvm"
    The status should eq 0
    The output should include "Force stopping VM myvm"
  End
End
