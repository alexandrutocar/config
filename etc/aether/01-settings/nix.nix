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
    # NOTE: Store size constraints.
    extraOptions = ''
      min-free = ${toString (builtins.ceil 68.5 * 1024 * 1024 * 1024)}
      max-free = ${toString (builtins.ceil 79.5 * 1024 * 1024 * 1024)}
    '';

    settings = {
      substituters = [
        "https://cache.aether.ip"
      ];

      trusted-public-keys = [
        "cache.aether.ip:YJj654vefxddqk3R5eEyDzFQXw6hDmVkJKVvxAqHnj4="
      ];

      trusted-users = ["cache" "builder"];
    };
  };
}
