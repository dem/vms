Describe "validate_name()"
  Include lib/common.sh

  It "accepts simple alphanumeric name"
    When call validate_name "myvm"
    The status should eq 0
  End

  It "accepts name with hyphens"
    When call validate_name "my-vm"
    The status should eq 0
  End

  It "accepts name with underscores"
    When call validate_name "my_vm"
    The status should eq 0
  End

  It "accepts name with numbers"
    When call validate_name "vm123"
    The status should eq 0
  End

  It "rejects name with spaces"
    When run validate_name "bad name"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "accepts name with dots"
    When call validate_name "vm.1"
    The status should eq 0
  End

  It "rejects name with slashes"
    When run validate_name "bad/name"
    The status should eq 1
    The stderr should include "Invalid VM name"
  End

  It "rejects name with shell metacharacters"
    When run validate_name 'bad;name'
    The status should eq 1
    The stderr should include "Invalid VM name"
  End
End

Describe "allocate_spice_port()"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/env"
  }

  cleanup() {
    rm -rf "$VMS_ROOT"
  }

  BeforeEach setup
  AfterEach cleanup

  It "defaults to 5900 when no port file exists"
    When call allocate_spice_port
    The output should eq 5900
    The contents of file "$VMS_ROOT/env/next_spice_port" should eq 5901
  End

  It "reads and increments existing port"
    echo 5910 > "$VMS_ROOT/env/next_spice_port"
    When call allocate_spice_port
    The output should eq 5910
    The contents of file "$VMS_ROOT/env/next_spice_port" should eq 5911
  End
End
