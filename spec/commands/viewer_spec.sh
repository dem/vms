Describe "vms viewer"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/env/vv"
  }

  cleanup() {
    rm -rf "$VMS_ROOT"
  }

  BeforeEach setup
  AfterEach cleanup

  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "myvm" ]] && return 0
        return 1
        ;;
      domstate)
        echo "${_vm_state:-running}"
        ;;
    esac
  }

  remote-viewer() {
    echo "SPICE_NOGRAB=$SPICE_NOGRAB remote-viewer $*"
    return 0
  }

  It "fails without arguments"
    When run source commands/viewer.sh
    The status should eq 1
    The stderr should include "usage: vms viewer"
  End

  It "fails when VM does not exist"
    When run source commands/viewer.sh "novm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "fails when VM is not running"
    _vm_state="shut off"
    When run source commands/viewer.sh "myvm"
    The status should eq 1
    The stderr should include "not running"
  End

  It "fails when .vv file is missing"
    _vm_state="running"
    When run source commands/viewer.sh "myvm"
    The status should eq 1
    The stderr should include "No viewer config"
  End

  It "succeeds when .vv file exists"
    _vm_state="running"
    cat > "$VMS_ROOT/env/vv/myvm.vv" <<EOF
[virt-viewer]
type=spice
host=127.0.0.1
port=5900
EOF
    When run source commands/viewer.sh "myvm"
    The status should eq 0
  End
End
