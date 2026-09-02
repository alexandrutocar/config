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
    settings = {
      trusted-users = ["cache" "builder"];

      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Store size constraints.
      # ────────────────────────────────────────────────────────────────────────
      min-free = builtins.ceil 68.5 * 1024 * 1024 * 1024;
      max-free = builtins.ceil 79.5 * 1024 * 1024 * 1024;
    };
  };
}
