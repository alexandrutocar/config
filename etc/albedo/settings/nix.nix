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
  pkgs,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
in {
  imports = singleton (self + /etc/shared/settings/nix.nix);

  nix = {
    distributedBuilds = true;

    extraOptions = ''
      min-free = ${toString (250 * 1024 * 1024 * 1024)}
      max-free = ${toString (300 * 1024 * 1024 * 1024)}
    '';

    settings = {
      builders-use-substitutes = true;
      trusted-users = ["root" "alex"];

      secret-key-files = [
        "/state/secrets/cache.aether.ip.key"
        "/state/secrets/cache.ueuie.dev.key"
      ];

      # post-build-hook = getExe (
      #   pkgs.custom.writeShell "post-build-hook.bash" {
      #     inputs = with pkgs; [];
      #     text = ''
      #       set -eu
      #       set -f
      #       export IFS=' '

      #       echo "Uploading paths" "$OUT_PATHS"
      #       exec nix copy --to "ssh://cache@aether.ip" "$OUT_PATHS"
      #     '';
      #   }
      # );
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
