# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █▄░█ █▀ █▀█ █░░ █▀▀
# █▄▄ █▄█ █░▀█ ▄█ █▄█ █▄▄ ██▄
#
# linux console, virtual console...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/01-settings/console.nix);
}
