# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# etcs, everything else...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/etcs.nix");

  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Using integrated graphics (keep i915) until GPU (remove nvidia)
  #       is needed again.
  #
  #       Relevant: https://github.com/NixOS/nixpkgs/issues/485579
  # ────────────────────────────────────────────────────────────────────────
  hardware.facter.detected.graphics.enable = false;
  boot.initrd.availableKernelModules = ["i915"];

  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Disable Bluetooth.
  # ────────────────────────────────────────────────────────────────────────
  hardware.facter.detected.bluetooth.enable = false;
  hardware.bluetooth.enable = false;

  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    # Ignore lid events - keep running.
    sensor.lid.enable = false;
  };
}
