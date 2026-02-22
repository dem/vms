Describe "iso freshness"
  Include lib/common.sh

  setup() {
    VMS_ROOT=$(mktemp -d)
    VMS_ISO=$(mktemp -d)
    VMS_ARCH_ISO="$VMS_ISO/archlinux-x86_64.iso"
    kernel_dir="$VMS_ISO/arch-boot"
  }
  cleanup() {
    rm -rf "$VMS_ROOT" "$VMS_ISO"
  }
  BeforeEach setup
  AfterEach cleanup

  Describe "iso_needs_download()"
    iso_needs_download() {
      if [[ ! -f "$VMS_ARCH_ISO" ]]; then
        echo "missing"
      elif [[ -n "$(find "$VMS_ARCH_ISO" -mtime +30 2>/dev/null)" ]]; then
        echo "stale"
      else
        echo "fresh"
      fi
    }

    It "returns missing when ISO does not exist"
      When call iso_needs_download
      The output should eq "missing"
    End

    It "returns fresh for a new ISO"
      touch "$VMS_ARCH_ISO"
      When call iso_needs_download
      The output should eq "fresh"
    End

    It "returns stale for an old ISO"
      touch -d "2 months ago" "$VMS_ARCH_ISO"
      When call iso_needs_download
      The output should eq "stale"
    End

    It "returns fresh for a 29-day-old ISO"
      touch -d "29 days ago" "$VMS_ARCH_ISO"
      When call iso_needs_download
      The output should eq "fresh"
    End

    It "returns stale for a 31-day-old ISO"
      touch -d "31 days ago" "$VMS_ARCH_ISO"
      When call iso_needs_download
      The output should eq "stale"
    End
  End

  Describe "kernel extraction needed"
    needs_extract() {
      [[ ! -f "$kernel_dir/vmlinuz-linux" ]] || [[ ! -f "$kernel_dir/initramfs-linux.img" ]]
    }

    It "needed when kernel dir does not exist"
      When call needs_extract
      The status should eq 0
    End

    It "needed when only kernel exists"
      mkdir -p "$kernel_dir"
      touch "$kernel_dir/vmlinuz-linux"
      When call needs_extract
      The status should eq 0
    End

    It "needed when only initrd exists"
      mkdir -p "$kernel_dir"
      touch "$kernel_dir/initramfs-linux.img"
      When call needs_extract
      The status should eq 0
    End

    It "not needed when both files exist"
      mkdir -p "$kernel_dir"
      touch "$kernel_dir/vmlinuz-linux"
      touch "$kernel_dir/initramfs-linux.img"
      When run needs_extract
      The status should eq 1
    End
  End

  Describe "stale ISO cleanup"
    It "removes arch-boot directory"
      mkdir -p "$kernel_dir"
      touch "$kernel_dir/vmlinuz-linux"
      touch "$kernel_dir/initramfs-linux.img"
      rm -rf "$kernel_dir"
      When call test -d "$kernel_dir"
      The status should eq 1
    End
  End
End
