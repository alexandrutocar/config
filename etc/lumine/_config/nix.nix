# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █ ▀▄▀
# █░▀█ █ █░█
#
# nix daemon, garbage collection, store optimization...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  self,
  lib,
  ...
}: let
  inherit (lib.extra.facter) report;
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + "/etc/shared/01-settings/nix.nix");

  # NIX
  # ---
  nix = {
    settings = let
      size = report.disk.extra.size "scsi-0QEMU_QEMU_HARDDISK_116491725" config.hardware.facter.report;
    in {
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Store size constraints.
      # ────────────────────────────────────────────────────────────────────────
      min-free = builtins.ceil (0.25 * size);
      max-free = builtins.ceil (0.50 * size);
    };
  };
}
