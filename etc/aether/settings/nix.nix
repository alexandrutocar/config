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

  nix.extraOptions = ''
    min-free = ${toString (builtins.ceil 68.5 * 1024 * 1024 * 1024)}
    max-free = ${toString (builtins.ceil 79.5 * 1024 * 1024 * 1024)}
  '';

  nix.settings.trusted-users = ["cache" "builder"];
}
