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

  nix = {
    # nix-collect-garbage --delete-older-than 365d
    gc = {
      automatic = true;
      dates = "06:15";
      options = "--delete-older-than 365d";
    };
  };
}
