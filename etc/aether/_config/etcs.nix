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
}: let 
  inherit (lib.modules) mkForce;
in  {
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/etcs.nix");

  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Using integrated graphics until GPU is needed again.
  #
  #       Relevant: https://github.com/NixOS/nixpkgs/issues/485579
  # ────────────────────────────────────────────────────────────────────────
  hardware.facter.detected.boot.graphics.kernelModules = mkForce ["i915"];

  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # Ignore lid events - keep running.
    sensor.lid.enable = false;
  };
}
