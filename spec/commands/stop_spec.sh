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
      shutdown)
        echo "shutdown $2"
        return 0
        ;;
    esac
  }

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

  It "fails when VM is not running"
    _vm_state="shut off"
    When run source commands/stop.sh "myvm"
    The status should eq 1
    The stderr should include "is not running"
  End

  It "shuts down a running VM"
    _vm_state="running"
    When run source commands/stop.sh "myvm"
    The status should eq 0
    The output should include "shutdown myvm"
  End
End
