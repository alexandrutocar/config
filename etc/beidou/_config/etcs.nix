{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/etcs.nix");

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
