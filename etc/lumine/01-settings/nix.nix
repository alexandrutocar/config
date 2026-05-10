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
}: {
  imports = lib.lists.singleton (self + /etc/shared/01-settings/nix.nix);
}
