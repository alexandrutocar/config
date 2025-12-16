# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀▄▀█ ▄▀█ █▀▀ █░█ █ █▄░█ █▀▀ █▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █░▀░█ █▀█ █▄▄ █▀█ █ █░▀█ ██▄ ▄█
#
# containers, docker, qemu, kvm, virsh...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  boot = {
    # enable kernel level virtualization
    kernelModules = [
      "kvm-amd"
    ];

    # enable input output memory management unit
    kernelParams = [
      "amd_iommu=on"
      "iommu=on"
    ];
  };

  environment.systemPackages = with pkgs; [
    virtiofsd
    spice

    # Management
    (nemu.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [copyDesktopItems];

      desktopItems = [
        (makeDesktopItem {
          name = "nemu";
          exec = "nemu %u";
          terminal = true;
          comment = oldAttrs.meta.description;
          desktopName = "Nemu";
          genericName = "Qemu Manager";
          categories = [];
          keywords = [];
        })
      ];
    }))
    qemu
    virt-viewer
    virt-manager
  ];

  # VIRTUALISATION PLATFORM MANAGEMENT
  # ----------------------------------
  virtualisation.libvirtd = {
    enable = true;

    # FULL-SYSTEM EMULATION
    # ---------------------
    qemu = {
      swtpm.enable = true;
    };
  };

  networking.firewall.trustedInterfaces = ["virbr0"];

  environment.persistence."/state".directories = [
    "/var/cache/libvirt"
    "/var/lib/libvirt"
  ];
}
