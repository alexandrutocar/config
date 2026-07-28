{pkgs, ...}: {
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  security = {
    forcePageTableIsolation = true;

    protectKernelImage = true;
  };
}
