Describe "autologin.sh"
  setup() {
    DESTDIR=$(mktemp -d)
    export DESTDIR
  }
  cleanup() { rm -rf "$DESTDIR"; }
  BeforeEach setup
  AfterEach cleanup

  # Mock systemctl (runs inside chroot in real use)
  systemctl() { :; }

  run_autologin() {
    # Source instead of exec so mocks apply
    (
      systemctl() { :; }
      getent() {
        echo "root:x:0:0::/root:/bin/bash"
        echo "testuser:x:1000:1000::/home/testuser:/bin/bash"
      }
      . "$PWD/guest/autologin.sh" "$@"
    )
  }

  serial_dropin="$DESTDIR/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf"
  tty1_dropin="$DESTDIR/etc/systemd/system/getty@tty1.service.d/autologin.conf"

  Describe "on root"
    It "creates serial console autologin dropin"
      When call run_autologin on root
      The status should eq 0
      Path "$DESTDIR/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" should be file
    End

    It "configures autologin for root user"
      run_autologin on root
      When call cat "$DESTDIR/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf"
      The output should include "--autologin root"
    End
  End

  Describe "on user"
    It "creates tty1 autologin dropin"
      When call run_autologin on user
      The status should eq 0
      Path "$DESTDIR/etc/systemd/system/getty@tty1.service.d/autologin.conf" should be file
    End

    It "configures autologin for first regular user"
      run_autologin on user
      When call cat "$DESTDIR/etc/systemd/system/getty@tty1.service.d/autologin.conf"
      The output should include "--autologin testuser"
    End
  End

  Describe "off root"
    It "removes serial console dropin"
      run_autologin on root
      When call run_autologin off root
      The status should eq 0
      Path "$DESTDIR/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" should not be exist
    End

    It "removes dropin directory when empty"
      run_autologin on root
      run_autologin off root
      When call test -d "$DESTDIR/etc/systemd/system/serial-getty@ttyS0.service.d"
      The status should eq 1
    End
  End

  Describe "off user"
    It "removes tty1 dropin"
      run_autologin on user
      When call run_autologin off user
      The status should eq 0
      Path "$DESTDIR/etc/systemd/system/getty@tty1.service.d/autologin.conf" should not be exist
    End
  End

  Describe "invalid arguments"
    It "rejects unknown target"
      When run run_autologin on bogus
      The status should eq 1
      The output should include "Unknown target"
    End

    It "rejects unknown action"
      When run run_autologin bogus root
      The status should eq 1
      The output should include "Unknown action"
    End
  End
End
