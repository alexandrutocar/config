# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# etcs, everything else...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + /etc/shared/settings/etcs.nix);

  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # Ignore lid events - keep running.
    sensor.lid.enable = false;
  };
}
