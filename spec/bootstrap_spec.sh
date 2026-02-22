Describe "bootstrap"
  Include lib/common.sh

  setup() {
    test_home=$(mktemp -d)
    VMS_ROOT=$(mktemp -d)
    mkdir -p "$VMS_ROOT/env"
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

  Describe "env/user creation"
    create_user_env() {
      local user_file="$VMS_ROOT/env/user"
      if [[ ! -f "$user_file" ]]; then
        local vm_user="${1:-$USER}"
        echo "$vm_user" > "$user_file"
      fi
    }

    It "creates env/user with provided username"
      When call create_user_env "testuser"
      The status should eq 0
      The contents of file "$VMS_ROOT/env/user" should eq "testuser"
    End

    It "defaults to \$USER when no input given"
      When call create_user_env ""
      The status should eq 0
      The contents of file "$VMS_ROOT/env/user" should eq "$USER"
    End

    It "skips if env/user already exists"
      echo "existing" > "$VMS_ROOT/env/user"
      When call create_user_env "newuser"
      The contents of file "$VMS_ROOT/env/user" should eq "existing"
    End
  End

  Describe "env/uid and env/gid creation"
    create_id_env() {
      local vm_user="$1"
      local uid_file="$VMS_ROOT/env/uid"
      local gid_file="$VMS_ROOT/env/gid"
      if [[ ! -f "$uid_file" ]] && id -u "$vm_user" &>/dev/null; then
        id -u "$vm_user" > "$uid_file"
      fi
      if [[ ! -f "$gid_file" ]] && id -g "$vm_user" &>/dev/null; then
        id -g "$vm_user" > "$gid_file"
      fi
    }

    It "creates uid/gid for existing host user"
      When call create_id_env "$USER"
      The status should eq 0
      The contents of file "$VMS_ROOT/env/uid" should eq "$(id -u "$USER")"
      The contents of file "$VMS_ROOT/env/gid" should eq "$(id -g "$USER")"
    End

    It "skips uid/gid for nonexistent user"
      When call create_id_env "no_such_user_xyzzy"
      The status should eq 0
      Path "$VMS_ROOT/env/uid" should not be exist
      Path "$VMS_ROOT/env/gid" should not be exist
    End

    It "skips uid if already exists"
      echo "9999" > "$VMS_ROOT/env/uid"
      When call create_id_env "$USER"
      The contents of file "$VMS_ROOT/env/uid" should eq "9999"
    End

    It "skips gid if already exists"
      echo "9999" > "$VMS_ROOT/env/gid"
      When call create_id_env "$USER"
      The contents of file "$VMS_ROOT/env/gid" should eq "9999"
    End
  End

  Describe "password validation"
    create_passwd_env() {
      local file="$1" pass="$2"
      if [[ ! -f "$file" ]]; then
        [[ -z "$pass" ]] && return 1
        echo "$pass" | openssl passwd -6 -stdin > "$file"
        chmod 600 "$file"
      fi
    }

    It "rejects empty password"
      When run create_passwd_env "$VMS_ROOT/env/root_passwd" ""
      The status should eq 1
      Path "$VMS_ROOT/env/root_passwd" should not be exist
    End

    It "creates password hash file"
      When call create_passwd_env "$VMS_ROOT/env/root_passwd" "testpass"
      The status should eq 0
      Path "$VMS_ROOT/env/root_passwd" should be exist
    End

    It "hash starts with \$6\$ (sha512)"
      create_passwd_env "$VMS_ROOT/env/root_passwd" "testpass"
      When call grep -c '^\$6\$' "$VMS_ROOT/env/root_passwd"
      The output should eq "1"
    End

    It "file has mode 600"
      create_passwd_env "$VMS_ROOT/env/root_passwd" "testpass"
      When call stat -c '%a' "$VMS_ROOT/env/root_passwd"
      The output should eq "600"
    End

    It "skips if file already exists"
      echo "existing_hash" > "$VMS_ROOT/env/root_passwd"
      When call create_passwd_env "$VMS_ROOT/env/root_passwd" "newpass"
      The contents of file "$VMS_ROOT/env/root_passwd" should eq "existing_hash"
    End
  End

  Describe "skip guards"
    It "skips directories when all exist"
      VMS_IMAGES=$(mktemp -d)
      VMS_ISO=$(mktemp -d)
      VMS_FILESYSTEMS=$(mktemp -d)
      mkdir -p "$VMS_FILESYSTEMS/pkg/shared"
      When call test -d "$VMS_IMAGES" -a -d "$VMS_ISO" -a -d "$VMS_FILESYSTEMS/pkg/shared"
      The status should eq 0
    End

    It "detects missing directory"
      When call test -d "/nonexistent_dir_xyzzy"
      The status should eq 1
    End

    It "skips ISO download when file exists"
      VMS_ARCH_ISO="$VMS_ROOT/test.iso"
      touch "$VMS_ARCH_ISO"
      When call test -f "$VMS_ARCH_ISO"
      The status should eq 0
    End

    It "detects missing ISO"
      When call test -f "$VMS_ROOT/nonexistent.iso"
      The status should eq 1
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

  Describe "relogin notice"
    check_needs_relogin() {
      local needs=0
      if ! echo "$1" | grep -qw libvirt; then
        needs=1
      fi
      if [[ -z "$2" ]]; then
        needs=1
      fi
      return $((1 - needs))
    }

    It "needed when user not in libvirt group"
      When call check_needs_relogin "wheel audio" "qemu:///system"
      The status should eq 0
    End

    It "needed when LIBVIRT_DEFAULT_URI unset"
      When call check_needs_relogin "wheel libvirt" ""
      The status should eq 0
    End

    It "not needed when group and env both set"
      When call check_needs_relogin "wheel libvirt audio" "qemu:///system"
      The status should eq 1
    End
  End
End
