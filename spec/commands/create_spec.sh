Describe "vms create"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    VMS_IMAGES=$(mktemp -d)
    VMS_ISO=$(mktemp -d)
    VMS_FILESYSTEMS=$(mktemp -d)
    VMS_PKG_CACHE=$(mktemp -d)
    VMS_ARCH_ISO="$VMS_ISO/archlinux-x86_64.iso"
    VMS_DEFAULT_MEMORY=2048
    VMS_DEFAULT_CPUS=2
    VMS_DEFAULT_DISK=20G
    VMS_DEFAULT_PROFILE=gui

    # Create required dirs and files
    mkdir -p "$VMS_ROOT/env/vv" "$VMS_ROOT/templates" "$VMS_ROOT/guest"
    mkdir -p "$VMS_ISO/arch-boot"
    touch "$VMS_ISO/arch-boot/vmlinuz-linux"
    touch "$VMS_ISO/arch-boot/initramfs-linux.img"
    echo "testuser" > "$VMS_ROOT/env/user"
    echo "roothash" > "$VMS_ROOT/env/root_passwd"
    echo "userhash" > "$VMS_ROOT/env/user_passwd"

    # Copy real template
    cp templates/viewer.vv "$VMS_ROOT/templates/viewer.vv"

    # Stub lib/vm.sh and lib/console.sh
    mkdir -p "$VMS_ROOT/lib"
    cat > "$VMS_ROOT/lib/vm.sh" <<'STUB'
wait_for_console() { return 0; }
wait_for_boot() { return 0; }
stop_vm() { return 0; }
STUB
    cat > "$VMS_ROOT/lib/console.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$VMS_ROOT/lib/console.sh"

    # Stub lib/iso.sh
    cat > "$VMS_ROOT/lib/iso.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$VMS_ROOT/lib/iso.sh"

  }

  cleanup() {
    rm -rf "$VMS_ROOT" "$VMS_IMAGES" "$VMS_ISO" "$VMS_FILESYSTEMS" "$VMS_PKG_CACHE"
  }

  BeforeEach setup
  AfterEach cleanup

  virsh() {
    case "$1" in
      dominfo) return 1 ;;
      dumpxml) echo "<domain><graphics type='spice' autoport='yes' listen='127.0.0.1'/></domain>" ;;
      define) cat >/dev/null; return 0 ;;
      start) return 0 ;;
      *) return 0 ;;
    esac
  }

  virt-install() { return 0; }
  virt-xml() { return 0; }

  blkid() { echo "FAKE-UUID"; }
  qemu-img() { return 0; }
  sudo() { "$@"; }

  Describe "name validation"
    It "rejects invalid VM name"
      When run source commands/create.sh "bad name"
      The status should eq 1
      The stderr should include "Invalid VM name"
    End
  End

  Describe "SPICE port allocation"
    It "defaults to port 5900 when no port file exists"
      When run source commands/create.sh "testvm"
      The status should eq 0
      The output should include "VM testvm ready"
      The file "$VMS_ROOT/env/next_spice_port" should be file
      The contents of file "$VMS_ROOT/env/next_spice_port" should eq 5901
    End

    It "reads and increments existing port file"
      echo 5905 > "$VMS_ROOT/env/next_spice_port"
      When run source commands/create.sh "testvm"
      The status should eq 0
      The output should include "SPICE port 5905"
      The contents of file "$VMS_ROOT/env/next_spice_port" should eq 5906
    End
  End

  Describe ".vv file generation"
    It "creates .vv file from template with correct port"
      When run source commands/create.sh "testvm"
      The status should eq 0
      The output should include "VM testvm ready"
      The file "$VMS_ROOT/env/vv/testvm.vv" should be file
    End

    It "substitutes port into template"
      echo 5910 > "$VMS_ROOT/env/next_spice_port"
      When run source commands/create.sh "testvm"
      The status should eq 0
      The output should include "VM testvm ready"
      The contents of file "$VMS_ROOT/env/vv/testvm.vv" should include "port=5910"
    End

    It "preserves other template fields"
      When run source commands/create.sh "testvm"
      The status should eq 0
      The output should include "VM testvm ready"
      The contents of file "$VMS_ROOT/env/vv/testvm.vv" should include "type=spice"
      The contents of file "$VMS_ROOT/env/vv/testvm.vv" should include "host=127.0.0.1"
      The contents of file "$VMS_ROOT/env/vv/testvm.vv" should include "resize-guest=always"
    End
  End
End
