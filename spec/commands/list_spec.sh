Describe "vms list"
  Include lib/common.sh

  virsh() {
    echo "called: virsh $*"
  }

  It "calls virsh list --all"
    When run source commands/list.sh
    The status should eq 0
    The output should include "called: virsh list --all"
  End
End
