Describe "vms bootstrap"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    VMS_IMAGES=$(mktemp -d)
    VMS_ISO=$(mktemp -d)
    VMS_FILESYSTEMS=$(mktemp -d)
    mkdir -p "$VMS_FILESYSTEMS/pkg"
    mkdir -p "$VMS_ROOT/templates"
    cp templates/network.xml "$VMS_ROOT/templates/network.xml"

    # Stub iso.sh
    mkdir -p "$VMS_ROOT/lib"
    cat > "$VMS_ROOT/lib/iso.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$VMS_ROOT/lib/iso.sh"

    # Fake HOME to avoid touching real bashrc/symlink
    HOME=$(mktemp -d)
    mkdir -p "$HOME/.local/bin"
    ln -s "$VMS_ROOT/vms" "$HOME/.local/bin/vms"
    echo 'LIBVIRT_DEFAULT_URI' > "$HOME/.bashrc"

    LIBVIRT_DEFAULT_URI=qemu:///system
  }

  cleanup() {
    rm -rf "$VMS_ROOT" "$VMS_IMAGES" "$VMS_ISO" "$VMS_FILESYSTEMS" "$HOME"
  }

  BeforeEach setup
  AfterEach cleanup

  # Mock all external commands to report "already done"
  pacman() { return 0; }
  systemctl() { return 0; }
  sudo() {
    case "$1" in
      virsh) return 0 ;;
      *) "$@" ;;
    esac
  }
  id() {
    case "$1" in
      -nG) echo "libvirt" ;;
      -u) echo "1000" ;;
      -g) echo "1000" ;;
    esac
  }
  openssl() { echo "hashed"; }

  It "fails on unknown option"
    When run source commands/bootstrap.sh "--bad"
    The status should eq 1
    The stderr should include "unknown option"
  End

  It "creates env/vv directory"
    # Pre-create passwd/user files so no read prompts
    mkdir -p "$VMS_ROOT/env"
    echo "hash" > "$VMS_ROOT/env/root_passwd"
    echo "hash" > "$VMS_ROOT/env/user_passwd"
    echo "testuser" > "$VMS_ROOT/env/user"
    echo "1000" > "$VMS_ROOT/env/uid"
    echo "1000" > "$VMS_ROOT/env/gid"
    When run source commands/bootstrap.sh
    The status should eq 0
    The output should include "Bootstrap complete"
    The path "$VMS_ROOT/env/vv" should be directory
  End

  It "creates root_passwd when missing"
    mkdir -p "$VMS_ROOT/env"
    echo "hash" > "$VMS_ROOT/env/user_passwd"
    echo "testuser" > "$VMS_ROOT/env/user"
    Data "secret"
    When run source commands/bootstrap.sh
    The status should eq 0
    The file "$VMS_ROOT/env/root_passwd" should be file
    The output should include "env/root_passwd created"
  End

  It "fails when root password is empty"
    mkdir -p "$VMS_ROOT/env"
    Data ""
    When run source commands/bootstrap.sh
    The status should eq 1
    The output should include "root password"
    The stderr should include "root password required"
  End

  It "skips passwd creation when files exist"
    mkdir -p "$VMS_ROOT/env"
    echo "hash" > "$VMS_ROOT/env/root_passwd"
    echo "hash" > "$VMS_ROOT/env/user_passwd"
    echo "testuser" > "$VMS_ROOT/env/user"
    echo "1000" > "$VMS_ROOT/env/uid"
    echo "1000" > "$VMS_ROOT/env/gid"
    When run source commands/bootstrap.sh
    The status should eq 0
    The output should not include "created"
  End

  Describe "subnet allocation"
    find_subnet() {
      local used_subnets
      used_subnets=" $(echo "$1" | tr '\n' ' ')"
      for i in $(seq 122 254); do
          if [[ "$used_subnets" != *" $i "* ]]; then
              echo "$i"
              return
          fi
      done
      echo ""
    }

    It "picks 122 when no subnets are used"
      When call find_subnet ""
      The output should eq 122
    End

    It "skips used subnets"
      When call find_subnet "122 123"
      The output should eq 124
    End

    It "handles non-contiguous used subnets"
      When call find_subnet "122 125"
      The output should eq 123
    End
  End

  It "creates uid and gid files"
    mkdir -p "$VMS_ROOT/env"
    echo "hash" > "$VMS_ROOT/env/root_passwd"
    echo "hash" > "$VMS_ROOT/env/user_passwd"
    echo "testuser" > "$VMS_ROOT/env/user"
    When run source commands/bootstrap.sh
    The status should eq 0
    The output should include "Bootstrap complete"
    The file "$VMS_ROOT/env/uid" should be file
    The contents of file "$VMS_ROOT/env/uid" should eq 1000
    The file "$VMS_ROOT/env/gid" should be file
    The contents of file "$VMS_ROOT/env/gid" should eq 1000
  End

  Describe "images/iso symlinks"
    setup_env() {
      mkdir -p "$VMS_ROOT/env"
      echo "hash" > "$VMS_ROOT/env/root_passwd"
      echo "hash" > "$VMS_ROOT/env/user_passwd"
      echo "testuser" > "$VMS_ROOT/env/user"
      echo "1000" > "$VMS_ROOT/env/uid"
      echo "1000" > "$VMS_ROOT/env/gid"
    }

    It "creates images and iso symlinks pointing at libvirt dirs"
      setup_env
      When run source commands/bootstrap.sh
      The status should eq 0
      The output should include "Symlinking images"
      The output should include "Symlinking iso"
      The path "$VMS_ROOT/images" should be symlink
      The path "$VMS_ROOT/iso" should be symlink
      The path "$VMS_ROOT/images" should be exist
      The path "$VMS_ROOT/iso" should be exist
    End

    It "skips symlink creation when already present"
      setup_env
      ln -s "$VMS_IMAGES" "$VMS_ROOT/images"
      ln -s "$VMS_ISO" "$VMS_ROOT/iso"
      When run source commands/bootstrap.sh
      The status should eq 0
      The output should not include "Symlinking images"
      The output should not include "Symlinking iso"
    End
  End
End
