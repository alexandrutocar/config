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
  imports = singleton (self + "/etc/shared/01-settings/nix.nix");

  # NIX
  # ---
  nix = {
    distributedBuilds = true;

    settings = {
      builders-use-substitutes = true;
      trusted-users = ["root" "alex"];

      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Store size constraints.
      # ────────────────────────────────────────────────────────────────────────
      min-free = 250 * 1024 * 1024 * 1024;
      max-free = 300 * 1024 * 1024 * 1024;
    };

    buildMachines = [
      {
        hostName = "aether.hosts.net.internal";
        speedFactor = 5800;
        sshUser = "builder";
        maxJobs = 4;
        systems = ["x86_64-linux"];
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
  };
}
