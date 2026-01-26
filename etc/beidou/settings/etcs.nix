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
    (self + /etc/shared/settings/etcs.nix)
  ];

  boot = {
    tmp.cleanOnBoot = true;
    kernel.sysctl = {
      "kernel.unprivileged_bpf_disabled" = 1;
    };
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
    {
      source = pkgs.fetchFromGitHub {
        owner = "drduh";
        repo = "yubikey-guide";
        rev = "7513db34cc7196a8b83e18b78264511c5aed4c71";
        hash = "sha256-Ne7BKmEJJKnJR1qngIqBGFFbKDA2Cn3pgqGX7jteRx8=";
      };
      target = "/guide";
    }
  ];
}
