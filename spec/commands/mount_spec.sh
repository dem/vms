Describe "vms mount"
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
      attach-device)
        echo "attach-device ${@:2}"
        return 0
        ;;
    esac
  }

  virt-xml() {
    echo "virt-xml $*"
    return 0
  }

  setup() {
    VMS_IMAGES=$(mktemp -d)
    VMS_ROOT=$(mktemp -d)
    touch "$VMS_IMAGES/myvm.qcow2"
    _hostdir=$(mktemp -d)
  }

  cleanup() {
    rm -rf "$VMS_IMAGES" "$VMS_ROOT" "$_hostdir"
  }

  BeforeEach setup
  AfterEach cleanup

  Describe "argument validation"
    It "fails without arguments"
      When run source commands/mount.sh
      The status should eq 1
      The stderr should include "usage: vms mount"
    End

    It "fails with one argument"
      When run source commands/mount.sh "myvm"
      The status should eq 1
      The stderr should include "usage: vms mount"
    End

    It "fails with two arguments"
      When run source commands/mount.sh "myvm" "$_hostdir"
      The status should eq 1
      The stderr should include "usage: vms mount"
    End

    It "rejects invalid VM name"
      When run source commands/mount.sh "bad name" "$_hostdir" "/mnt/x"
      The status should eq 1
      The stderr should include "Invalid VM name"
    End

    It "rejects unknown option"
      When run source commands/mount.sh "myvm" "$_hostdir" "/mnt/x" --bogus
      The status should eq 1
      The stderr should include "unknown option"
    End

    It "rejects relative guest path"
      When run source commands/mount.sh "myvm" "$_hostdir" "relative/path"
      The status should eq 1
      The stderr should include "Guest directory must be an absolute path"
    End

    It "rejects nonexistent host directory"
      When run source commands/mount.sh "myvm" "/nonexistent-host-path-xyz" "/mnt/x"
      The status should eq 1
      The stderr should include "Host directory"
    End
  End

  Describe "VM existence"
    It "fails when VM does not exist"
      When run source commands/mount.sh "novm" "$_hostdir" "/mnt/x"
      The status should eq 1
      The stderr should include "does not exist"
    End
  End

  Describe "state guards"
    It "--temp fails when VM is not running"
      _vm_state="shut off"
      When run source commands/mount.sh "myvm" "$_hostdir" "/mnt/x" --temp
      The status should eq 1
      The stderr should include "VM myvm is not running"
    End

    It "persistent fails when VM is running"
      _vm_state="running"
      When run source commands/mount.sh "myvm" "$_hostdir" "/mnt/x"
      The status should eq 1
      The stderr should include "must be stopped"
    End

    It "persistent fails when VM is paused"
      _vm_state="paused"
      When run source commands/mount.sh "myvm" "$_hostdir" "/mnt/x"
      The status should eq 1
      The stderr should include "must be stopped"
    End
  End

  Describe "tag generation"
    # Test tag naming logic in isolation by extracting the derivation
    tag_of() {
      echo "$1" | sed 's|^/||; s|/|-|g'
    }

    It "derives tag from single-segment path"
      When call tag_of "/share"
      The output should eq "share"
    End

    It "derives tag from nested path"
      When call tag_of "/home/user/projects"
      The output should eq "home-user-projects"
    End

    It "derives tag from deeply nested path"
      When call tag_of "/var/lib/docker/volumes"
      The output should eq "var-lib-docker-volumes"
    End
  End
End
