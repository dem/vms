Describe "vms umount"
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
      dumpxml)
        echo "${_vm_xml:-<domain></domain>}"
        ;;
      detach-device)
        echo "detach-device ${@:2}"
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
    mkdir -p "$VMS_ROOT/lib"
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
stop_vm() { return 0; }
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
    When run source commands/umount.sh
    The status should eq 1
    The stderr should include "usage: vms umount"
  End

  It "fails with only VM name"
    When run source commands/umount.sh "myvm"
    The status should eq 1
    The stderr should include "usage: vms umount"
  End

  It "rejects invalid VM name"
    When run source commands/umount.sh "bad name" "/mnt/x"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "fails when VM does not exist"
    When run source commands/umount.sh "novm" "/mnt/x"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "rejects relative guest path"
    When run source commands/umount.sh "myvm" "relative/path"
    The status should eq 1
    The stderr should include "Guest directory must be an absolute path"
  End

  It "fails when no mount exists for guestdir"
    _vm_xml="<domain><devices></devices></domain>"
    When run source commands/umount.sh "myvm" "/mnt/nosuch"
    The status should eq 1
    The stderr should include "No mount found"
  End

  Describe "tag matching from XML"
    It "finds base tag in XML"
      _vm_xml="<domain><devices><filesystem><target dir='mnt-share'/></filesystem></devices></domain>"
      _vm_state="running"
      When run source commands/umount.sh "myvm" "/mnt/share"
      The status should eq 0
      The output should include "Unmounted /mnt/share (mnt-share)"
    End

    It "finds suffixed tag in XML"
      _vm_xml="<domain><devices><filesystem><target dir='mnt-share-1'/></filesystem></devices></domain>"
      _vm_state="running"
      When run source commands/umount.sh "myvm" "/mnt/share"
      The status should eq 0
      The output should include "Unmounted /mnt/share (mnt-share-1)"
    End
  End

  Describe "state guard"
    It "rejects intermediate states"
      _vm_xml="<domain><devices><filesystem><target dir='mnt-x'/></filesystem></devices></domain>"
      _vm_state="paused"
      When run source commands/umount.sh "myvm" "/mnt/x"
      The status should eq 1
      The stderr should include "stop or start"
    End
  End
End
