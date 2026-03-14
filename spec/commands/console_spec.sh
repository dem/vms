Describe "vms console"
  Include lib/common.sh

  # Mock virsh
  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "exists" ]] && return 0
        return 1
        ;;
      console)
        echo "connected to $2"
        return 0
        ;;
    esac
  }

  It "fails without arguments"
    When run source commands/console.sh
    The status should eq 1
    The stderr should include "usage: vms console"
  End

  It "fails when VM does not exist"
    When run source commands/console.sh "novm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "connects to existing VM"
    When run source commands/console.sh "exists"
    The status should eq 0
    The output should include "connected to exists"
  End
End
