{
  modulesPath,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.modules) mkForce;
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (self + /etc/shared/settings/initrd.nix)
    (self + /etc/shared/settings/nix.nix)
  ];

  boot = {
    tmp.cleanOnBoot = true;
    kernel.sysctl = {"kernel.unprivileged_bpf_disabled" = 1;};
  };

  swapDevices = [];

  nix.settings.trusted-users = ["alex"];

  boot.supportedFilesystems = mkForce [
    "vfat"
  ];

  isoImage.contents = [
    {
      source = pkgs.writeText "utilities.txt" ''
        paperkey
        pgpdump
        parted

        age

        yubikey-manager
        yubico-piv-tool

        ent

        rng-tools
        diceware
        pwgen

        pcsc-tools
        cfssl
      '';
      target = "/utilities.txt"; # /iso/utilities.txt
    }
  ];
}
