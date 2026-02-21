Describe "step()"
  Include lib/common.sh

  Describe "normal mode"
    BeforeEach 'VMS_VERBOSE=0'

    It "prints step message and runs command"
      When call step "Doing thing" true
      The status should eq 0
      The output should eq "Doing thing"
    End

    It "hides command output on success"
      When call step "Listing" echo "hidden output"
      The status should eq 0
      The output should eq "Listing"
    End

    It "shows FAILED with last error line on failure"
      failing_cmd() { echo "line1"; echo "the error"; return 1; }
      When run step "Bad step" failing_cmd
      The status should eq 1
      The output should eq "Bad step"
      The stderr should include "FAILED: the error"
    End

    It "dumps full output on failure"
      failing_cmd() { echo "line1"; echo "line2"; return 1; }
      When run step "Bad step" failing_cmd
      The status should eq 1
      The output should eq "Bad step"
      The stderr should include "--- output ---"
      The stderr should include "line1"
      The stderr should include "line2"
    End

    It "falls back to step name when output is empty"
      When run step "Empty fail" false
      The status should eq 1
      The output should eq "Empty fail"
      The stderr should include "FAILED: Empty fail"
    End
  End

  Describe "verbose mode"
    BeforeEach 'VMS_VERBOSE=1'

    It "prints ==> prefix and shows command output"
      When call step "Doing thing" echo "visible output"
      The status should eq 0
      The line 1 of output should eq "==> Doing thing"
      The line 2 of output should eq "visible output"
    End

    It "propagates failure exit code"
      When run step "Failing" false
      The status should eq 1
      The output should eq "==> Failing"
    End
  End
End

Describe "info()"
  Include lib/common.sh

  It "prints plain message in normal mode"
    VMS_VERBOSE=0
    When call info "Hello"
    The output should eq "Hello"
  End

  It "prints ==> prefix in verbose mode"
    VMS_VERBOSE=1
    When call info "Hello"
    The output should eq "==> Hello"
  End
End
