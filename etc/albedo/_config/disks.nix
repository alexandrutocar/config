# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █ █▀ █▄▀ █▀
# █▄▀ █ ▄█ █░█ ▄█
#
# disks, swap, filesystems...
#
# ────────────────────────────────────────────────────────────────────────
{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  boot = {
    initrd = {
      availableKernelModules = [
        # advanced host controller interface
        "ahci"
        # non-volatile memory express driver
        "nvme"
        # secure digital
        "sd_mod"
        # universal serial bus
        "usb_storage"
        # extensible host controller interface (over) peripheral component interconnect
        "xhci_pci"
      ];

      luks.devices = {
        pool = {
          bypassWorkqueues = true;
          device = "/dev/disk/by-uuid/66863f41-ea06-4943-b8cf-7001c6188a44";
          allowDiscards = true;
        };
      };

      systemd.services = {
        rollback = {
          description = "clear / of any state.";
          wantedBy = ["initrd.target"];
          after = ["zfs-import-pool.service"];
          before = ["sysroot.mount"];
          path = with pkgs; [zfs];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            zfs rollback -r pool/root@blank && echo ">> >> Rollback Compete << <<"
          '';
        };
      };
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This is a safeguard against bypassing important checks.
    # ────────────────────────────────────────────────────────────────────────
    zfs.forceImportRoot = false;

    kernelParams = [
      # Maximum size of Arc cache is 1GB.
      "zfs.zfs_arc_max=1073741824" # bytes
    ];
  };

  # GVFS
  # ----
  services.gvfs.enable = true;

  fileSystems = {
    # Boot
    "/boot" = {
      device = "/dev/disk/by-uuid/12CE-A600";
      fsType = "vfat";
      options = [
        "fmask=0022" # file      permissions mask: 666 (default) - 022 = 644 ~ rw-r--r--
        "dmask=0022" # directory permissions mask: 777 (default) - 022 = 755 ~ rwxr-xr-x
        "umask=0077" # universal permissions mask: 600 ~ rw------- / 700 ~ rwx------
      ];
    };

    # Pool
    "/blobs" = {
      fsType = "zfs";
      device = "pool/blobs";
    };
    "/home" = {
      fsType = "zfs";
      device = "pool/home";
    };
    "/nix" = {
      fsType = "zfs";
      device = "pool/nix";
      neededForBoot = true;
    };
    "/" = {
      fsType = "zfs";
      device = "pool/root";
    };
    "/state" = {
      fsType = "zfs";
      device = "pool/state";
      neededForBoot = true;
    };
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/d9e39bd1-ec5f-401b-ba2f-bb1bfb2b9df1";
    }
  ];

  # required by zfs to uniquely identify the machine
  # in a networked pool consisting of many nodes.
  networking.hostId = mkDefault "e9a5df63";
}
