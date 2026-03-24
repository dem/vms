Describe "vms clone"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    VMS_IMAGES=$(mktemp -d)
    VMS_FILESYSTEMS=$(mktemp -d)
    mkdir -p "$VMS_ROOT/env/vv" "$VMS_ROOT/templates" "$VMS_ROOT/lib"
    cp templates/viewer.vv "$VMS_ROOT/templates/viewer.vv"

    # Create source disk
    echo "diskdata" > "$VMS_IMAGES/src.qcow2"

    # Stub lib/vm.sh and lib/console.sh
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
wait_for_boot() { return 0; }
stop_vm() { return 0; }
STUB
    cat > "$VMS_ROOT/lib/console.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$VMS_ROOT/lib/console.sh"
  }

  cleanup() {
    rm -rf "$VMS_ROOT" "$VMS_IMAGES" "$VMS_FILESYSTEMS"
  }

  BeforeEach setup
  AfterEach cleanup

  virsh() {
    case "$1" in
      dominfo)
        [[ "$2" == "src" ]] && return 0
        return 1
        ;;
      start) return 0 ;;
      *) return 0 ;;
    esac
  }

  virt-clone() { return 0; }
  virt-xml() { return 0; }
  sudo() { "$@"; }

  It "rejects invalid VM name"
    When run source commands/clone.sh "src" "bad name"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "fails without arguments"
    When run source commands/clone.sh
    The status should eq 1
    The stderr should include "usage: vms clone"
  End

  It "fails with only source"
    When run source commands/clone.sh "src"
    The status should eq 1
    The stderr should include "usage: vms clone"
  End

  It "fails when source VM does not exist"
    When run source commands/clone.sh "novm" "newvm"
    The status should eq 1
    The stderr should include "does not exist"
  End

  It "fails when target already exists"
    virsh() {
      case "$1" in
        dominfo) return 0 ;;
      esac
    }
    When run source commands/clone.sh "src" "newvm"
    The status should eq 1
    The stderr should include "already exists"
  End

  It "creates a full copy of the disk"
    When run source commands/clone.sh "src" "newvm"
    The status should eq 0
    The output should include "Cloning src to newvm"
    The output should include "Copying disk"
    The file "$VMS_IMAGES/newvm.qcow2" should be file
  End

  It "shows verbose output with -v"
    VMS_VERBOSE=1
    When run source commands/clone.sh "src" "newvm"
    The status should eq 0
    The output should include "==> Cloning src to newvm"
    The output should include "==> Copying disk"
    The output should include "==> VM newvm ready"
  End

  It "allocates port and creates .vv file"
    echo 5920 > "$VMS_ROOT/env/next_spice_port"
    When run source commands/clone.sh "src" "newvm"
    The status should eq 0
    The output should include "VM newvm ready"
    The contents of file "$VMS_ROOT/env/next_spice_port" should eq 5921
    The file "$VMS_ROOT/env/vv/newvm.vv" should be file
    The contents of file "$VMS_ROOT/env/vv/newvm.vv" should include "port=5920"
  End
End
