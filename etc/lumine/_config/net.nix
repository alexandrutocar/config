# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, wireless, wired...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/01-settings/net.nix);
}
