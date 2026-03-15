Describe "vms destroy"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    VMS_IMAGES=$(mktemp -d)
    VMS_FILESYSTEMS=$(mktemp -d)
    mkdir -p "$VMS_ROOT/env/vv"
  }

  cleanup() {
    rm -rf "$VMS_ROOT" "$VMS_IMAGES" "$VMS_FILESYSTEMS"
  }

  BeforeEach setup
  AfterEach cleanup

  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "myvm" ]] && return 0
        return 1
        ;;
      destroy) return 0 ;;
      undefine) return 0 ;;
    esac
  }

  sudo() { "$@"; }

  It "fails without arguments"
    When run source commands/destroy.sh
    The status should eq 1
    The stderr should include "usage: vms destroy"
  End

  It "fails when VM does not exist"
    When run source commands/destroy.sh "novm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "warns about orphaned disk when VM does not exist"
    touch "$VMS_IMAGES/novm.qcow2"
    When run source commands/destroy.sh "novm"
    The status should eq 1
    The stderr should include "disk remains"
  End

  It "deletes disk when user confirms"
    touch "$VMS_IMAGES/myvm.qcow2"
    Data "y"
    When run source commands/destroy.sh "myvm"
    The status should eq 0
    The output should include "Removed"
    The file "$VMS_IMAGES/myvm.qcow2" should not be file
  End

  It "keeps disk when user declines"
    touch "$VMS_IMAGES/myvm.qcow2"
    Data "n"
    When run source commands/destroy.sh "myvm"
    The status should eq 0
    The output should include "Keeping"
    The file "$VMS_IMAGES/myvm.qcow2" should be file
  End

  It "always removes package cache"
    mkdir -p "$VMS_FILESYSTEMS/pkg/myvm"
    touch "$VMS_FILESYSTEMS/pkg/myvm/somefile"
    When run source commands/destroy.sh "myvm"
    The status should eq 0
    The output should include "destroyed"
    The path "$VMS_FILESYSTEMS/pkg/myvm" should not be exist
  End

  It "removes viewer config"
    touch "$VMS_ROOT/env/vv/myvm.vv"
    When run source commands/destroy.sh "myvm"
    The status should eq 0
    The output should include "destroyed"
    The file "$VMS_ROOT/env/vv/myvm.vv" should not be file
  End
End
