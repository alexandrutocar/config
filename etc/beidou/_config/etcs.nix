{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/etcs.nix");

  hardware = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: Disable Bluetooth.
    # ────────────────────────────────────────────────────────────────────────
    facter.detected.bluetooth.enable = false;
    bluetooth.enable = false;

    # Ignore lid events - keep running.
    sensor.lid.enable = false;
  };

  powerManagement.cpuFreqGovernor = "performance";
}
