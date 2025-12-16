# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █ ▀▄▀
# █░▀█ █ █░█
#
# nix daemon, garbage collection, store optimisation...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/settings/nix.nix);

  nixpkgs.hostPlatform.system = "x86_64-linux";

  nix = {
    distributedBuilds = true;

    settings = {
      builders-use-substitutes = true;
      trusted-users = ["root" "@wheel"];
    };

    buildMachines = [
      {
        hostName = "aether.ip";

        systems = ["x86_64-linux"];
        maxJobs = 1;

        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
    ];
  };
}
