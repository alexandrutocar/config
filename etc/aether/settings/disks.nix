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
    initrd.availableKernelModules = [
      "ahci" # advanced host controller interface
      "sd_mod" # secure digital
      "usb_storage" # universal serial bus
      "xhci_pci" # extensible host controller interface (over) peripheral component interconnect
    ];

    kernelParams = [
      # Maximum size of Arc cache and reserved space add up to
      # leave exactly 12.5 GiB free for the rest of the system.
      "zfs.zfs_arc_max=2139856896" # bytes
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
      device = "/dev/disk/by-uuid/F3AC-84D9";
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
      fsType = "zfs";
      device = "pool/state";
      neededForBoot = true;
      options = ["zfsutil"];
    };

    # Data
    "/archive" = {
      device = "data/archive";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/backup" = {
      device = "data/backup";
      fsType = "zfs";
      options = ["zfsutil"];
    };
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/f342a395-2d19-43b3-af61-78fb0a9b6051";
    }
  ];

  # required by zfs to uniquely identify the machine
  # in a networked pool consisting of many nodes.
  networking.hostId = "8425e349";
}
