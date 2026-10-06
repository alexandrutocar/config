# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █ █▀ █▄▀ █▀
# █▄▀ █ ▄█ █░█ ▄█
#
# disks, swap, filesystems...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  boot = {
    initrd = {
      availableKernelModules = ["usb_storage"]; # universal serial bus

      luks.devices = {
        pool = {
          bypassWorkqueues = true;
          device = "/dev/disk/by-uuid/a576ca18-868e-440d-bca3-5c70f2f83537";
          allowDiscards = true;
        };
      };
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This is a safeguard against bypassing important checks.
    # ────────────────────────────────────────────────────────────────────────
    zfs.forceImportRoot = false;

    kernelParams = [
      # Maximum size of Arc cache and reserved space add up to
      # leave exactly 7.0 GiB free for the rest of the system.
      "zfs.zfs_arc_max=1069928448" # bytes
    ];
  };

  fileSystems = {
    # Root
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["defaults" "size=25%" "mode=755"];
    };

    # Boot
    "/boot" = {
      device = "/dev/disk/by-uuid/D6D9-C32D";
      fsType = "vfat";
      options = [
        "fmask=0022" # file      permissions mask: 666 (default) - 022 = 644 ~ rw-r--r--
        "dmask=0022" # directory permissions mask: 777 (default) - 022 = 755 ~ rwxr-xr-x
        "umask=0077" # universal permissions mask: 600 ~ rw------- / 700 ~ rwx------
      ];
    };

    # Pool
    "/blobs" = {
      device = "pool/blobs";
      fsType = "zfs";
      neededForBoot = true; # required by the impermanence module.
      options = ["zfsutil"];
    };
    "/home" = {
      device = "pool/home";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/nix" = {
      device = "pool/nix";
      fsType = "zfs";
      neededForBoot = true;
      options = ["zfsutil"];
    };
    "/root" = {
      device = "pool/root";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/state" = {
      device = "pool/state";
      fsType = "zfs";
      neededForBoot = true;
      options = ["zfsutil"];
    };
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/ad9effd2-d0b7-4356-be90-6550799d0e60";
    }
  ];

  # required by zfs to uniquely identify the machine
  # in a networked pool consisting of many nodes.
  networking.hostId = "a317445c";
}
