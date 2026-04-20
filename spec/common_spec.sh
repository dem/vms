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

Describe "memory_to_mb()"
  Include lib/common.sh

  It "converts G suffix to MB"
    When call memory_to_mb "4G"
    The output should eq 4096
  End

  It "accepts lowercase g"
    When call memory_to_mb "2g"
    The output should eq 2048
  End

  It "converts M suffix as-is"
    When call memory_to_mb "512M"
    The output should eq 512
  End

  It "accepts lowercase m"
    When call memory_to_mb "256m"
    The output should eq 256
  End

  It "rejects plain number without suffix"
    When run memory_to_mb "4096"
    The status should eq 1
    The stderr should include "G or M suffix"
  End

  It "rejects garbage input"
    When run memory_to_mb "4X"
    The status should eq 1
    The stderr should include "G or M suffix"
  End
End

Describe "parse_hw_flags()"
  Include lib/common.sh

  It "leaves all values empty when no flags"
    When call parse_hw_flags foo bar
    The status should eq 0
    The variable HW_MEMORY should eq ""
    The variable HW_CPUS should eq ""
    The variable HW_DISPLAYS should eq ""
  End

  It "passes through non-HW args in HW_REMAINING"
    parse_hw_flags foo bar
    The variable "HW_REMAINING[0]" should eq "foo"
    The variable "HW_REMAINING[1]" should eq "bar"
  End

  It "extracts --memory"
    parse_hw_flags --memory 4096
    The variable HW_MEMORY should eq 4096
  End

  It "extracts --cpus"
    parse_hw_flags --cpus 4
    The variable HW_CPUS should eq 4
  End

  It "extracts --displays"
    parse_hw_flags --displays 2
    The variable HW_DISPLAYS should eq 2
  End

  It "extracts all three at once"
    parse_hw_flags --memory 4096 --cpus 4 --displays 2
    The variable HW_MEMORY should eq 4096
    The variable HW_CPUS should eq 4
    The variable HW_DISPLAYS should eq 2
  End

  It "separates HW flags from positional args"
    parse_hw_flags myvm gui --memory 4096 --cpus 4
    The variable HW_MEMORY should eq 4096
    The variable HW_CPUS should eq 4
    The variable "HW_REMAINING[0]" should eq "myvm"
    The variable "HW_REMAINING[1]" should eq "gui"
  End

  It "handles mixed order"
    parse_hw_flags --memory 2048 myvm --cpus 2 gui
    The variable HW_MEMORY should eq 2048
    The variable HW_CPUS should eq 2
    The variable "HW_REMAINING[0]" should eq "myvm"
    The variable "HW_REMAINING[1]" should eq "gui"
  End
End
