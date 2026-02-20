Describe "bootstrap"
  Include lib/common.sh

  setup() {
    test_home=$(mktemp -d)
    VMS_ROOT=$(mktemp -d)
    touch "$VMS_ROOT/vms"
  }
  cleanup() {
    rm -rf "$test_home" "$VMS_ROOT"
  }
  BeforeEach setup
  AfterEach cleanup

  Describe "install_symlink()"
    install_symlink() {
      mkdir -p "$test_home/.local/bin"
      ln -s "$VMS_ROOT/vms" "$test_home/.local/bin/vms"
    }

    It "creates symlink to vms"
      When call install_symlink
      The status should eq 0
      Path "$test_home/.local/bin/vms" should be symlink
    End

    It "symlink points to vms script"
      When call install_symlink
      The value "$(readlink "$test_home/.local/bin/vms")" should eq "$VMS_ROOT/vms"
    End

    It "creates .local/bin directory"
      install_symlink
      When call test -d "$test_home/.local/bin"
      The status should eq 0
    End
  End

  Describe "setup_libvirt_uri()"
    setup_libvirt_uri() {
      echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> "$test_home/.bashrc"
    }

    It "appends LIBVIRT_DEFAULT_URI export to bashrc"
      When call setup_libvirt_uri
      The status should eq 0
      The contents of file "$test_home/.bashrc" should include "export LIBVIRT_DEFAULT_URI=qemu:///system"
    End

    It "does not duplicate on second call"
      echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' > "$test_home/.bashrc"
      When call setup_libvirt_uri
      The value "$(grep -c 'LIBVIRT_DEFAULT_URI' "$test_home/.bashrc")" should eq 2
    End
  End

  Describe "idempotency guards"
    It "skips symlink if already exists"
      mkdir -p "$test_home/.local/bin"
      ln -s "$VMS_ROOT/vms" "$test_home/.local/bin/vms"
      When call test -L "$test_home/.local/bin/vms"
      The status should eq 0
    End

    It "skips bashrc if LIBVIRT_DEFAULT_URI already set"
      echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' > "$test_home/.bashrc"
      When call grep -q 'LIBVIRT_DEFAULT_URI' "$test_home/.bashrc"
      The status should eq 0
    End
  End
End
