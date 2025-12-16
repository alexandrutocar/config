# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █░█
# █▄█ █▀▀ █▄█
#
# gpu, nvidia, cuda...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    open = false;
  };

  boot.blacklistedKernelModules = ["nouveau"];
}
