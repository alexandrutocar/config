# ────────────────────────────────────────────────────────────────────────
#
# █▀ █░█ █▀▀ █░░ █░░
# ▄█ █▀█ ██▄ █▄▄ █▄▄
#
# shell, terminal, utilities...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/settings/shell.nix);
}
