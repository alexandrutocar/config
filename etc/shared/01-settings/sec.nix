{pkgs, ...}: {
  boot.kernelPackages = pkgs.linuxPackages_7_0;

  security = {
    forcePageTableIsolation = true;

    protectKernelImage = true;
  };
}
