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
  imports = singleton (self + /etc/shared/01-settings/nix.nix);

  # NIX
  # ---
  nix = {
    distributedBuilds = true;

    # NOTE: Store size constraints.
    extraOptions = ''
      min-free = ${toString (250 * 1024 * 1024 * 1024)}
      max-free = ${toString (300 * 1024 * 1024 * 1024)}
    '';

    settings = {
      builders-use-substitutes = true;

      secret-key-files = [
        "/state/secrets/cache.aether.ip.key"
        "/state/secrets/cache.ueuie.dev.key"
      ];

      substituters = [
        "https://cache.aether.ip"
      ];

      trusted-public-keys = [
        "cache.aether.ip:YJj654vefxddqk3R5eEyDzFQXw6hDmVkJKVvxAqHnj4="
      ];

      trusted-users = ["root" "alex"];
    };

    buildMachines = [
      {
        hostName = "aether.ip";
        speedFactor = 5800;
        sshUser = "builder";
        maxJobs = 4;
        systems = ["x86_64-linux"];
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
  };
}
