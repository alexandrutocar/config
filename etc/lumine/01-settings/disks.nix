# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █ █▀ █▄▀ █▀
# █▄▀ █ ▄█ █░█ ▄█
#
# disks, swap, filesystems...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.facter) report;
in {
  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];


    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This is a safeguard against bypassing important checks.
    # ────────────────────────────────────────────────────────────────────────
    zfs.forceImportRoot = false;
    
    kernelParams = let
      size = report.memory.extra.size config.hardware.facter.report;
    in [
      # NOTE: Cap Arc cache memory usage at 25% of total available
      #       memory (bytes).
      "zfs.zfs_arc_max=${toString (builtins.ceil (0.25 * size))}"
    ];
  };

  fileSystems = {
    # Root
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["defaults" "size=10%" "mode=755"];
    };

    # Boot
    "/boot" = {
      device = "/dev/disk/by-uuid/EE58-DFC9";
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
  };

  # required by zfs to uniquely identify the machine
  # in a networked pool consisting of many nodes.
  networking.hostId = "8a098e8c";
}
