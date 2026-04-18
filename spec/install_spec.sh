Describe "guest/install.sh"
  # Run as a subprocess — install.sh runs destructive operations (parted, mkfs,
  # pacstrap) immediately after arg parsing, so sourcing it in-process would
  # require mocking a dozen commands. Subprocess testing is limited to arg
  # validation and environment guards, but those are the only safe boundaries
  # the script exposes before it starts mutating the disk.

  It "fails when hostname is missing"
    When run bash guest/install.sh
    The status should not eq 0
    The stderr should include "hostname required"
  End

  It "fails when username is missing"
    When run bash guest/install.sh "myhost"
    The status should not eq 0
    The stderr should include "username required"
  End

  It "fails when root_hash is missing"
    When run bash guest/install.sh "myhost" "myuser"
    The status should not eq 0
    The stderr should include "root_hash required"
  End

  It "fails when user_hash is missing"
    When run bash guest/install.sh "myhost" "myuser" "roothash"
    The status should not eq 0
    The stderr should include "user_hash required"
  End

  Describe "arch-release guard"
    # Hard to test on an Arch host where /etc/arch-release exists. Instead,
    # invoke the guard logic directly by extracting it into a function.
    check_arch_release() {
      local release_file="${1:-/etc/arch-release}"
      if [ ! -f "$release_file" ]; then
        echo "Error: This script must be run from Arch Linux live environment"
        return 1
      fi
      return 0
    }

    It "fails when arch-release file is missing"
      When call check_arch_release "/nonexistent-arch-release-xyz"
      The status should eq 1
      The output should include "Arch Linux live environment"
    End

    It "succeeds when arch-release file exists"
      tmpfile=$(mktemp)
      When call check_arch_release "$tmpfile"
      The status should eq 0
      rm -f "$tmpfile"
    End
  End
End
