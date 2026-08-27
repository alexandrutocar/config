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

  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # Ignore lid events - keep running.
    sensor.lid.enable = false;
  };
}
