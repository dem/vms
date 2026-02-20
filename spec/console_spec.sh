Describe "console.sh"
  It "shows usage when called without arguments"
    When run ./lib/console.sh
    The status should eq 1
    The output should include "Usage:"
  End

  It "send rejects missing arguments"
    When run ./lib/console.sh send myvm
    The status should eq 1
    The stderr should include "usage:"
  End

  It "send fails on nonexistent file"
    When run ./lib/console.sh send myvm /nonexistent /tmp/dest
    The status should eq 1
    The stderr should include "file not found"
  End

  It "exec fails on nonexistent script"
    When run ./lib/console.sh exec myvm /nonexistent
    The status should eq 1
    The stderr should include "file not found"
  End

  It "run rejects missing arguments"
    When run ./lib/console.sh run myvm
    The status should eq 1
    The stderr should include "usage:"
  End
End
