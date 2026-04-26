# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █░█
# █▄█ █▀▀ █▄█
#
# gpu, nvidia, cuda...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "580.142";
      sha256_64bit = "sha256-IJFfzz/+icNVDPk7YKBKKFRTFQ2S4kaOGRGkNiBEdWM=";
      sha256_aarch64 = "sha256-jntr88SpTYR648P1rizQjB/8KleBoa14Ay12vx8XETM=";
      openSha256 = "sha256-v968LbRqy8jB9+yHy9ceP2TDdgyqfDQ6P41NsCoM2AY=";
      settingsSha256 = "sha256-BnrIlj5AvXTfqg/qcBt2OS9bTDDZd3uhf5jqOtTMTQM=";
      persistencedSha256 = "sha256-il403KPFAnDbB+dITnBGljhpsUPjZwmLjGt8iPKuBqw=";
    };

    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    open = false;

    dynamicBoost.enable = lib.mkForce false;
  };

  boot.blacklistedKernelModules = ["nouveau"];
}
