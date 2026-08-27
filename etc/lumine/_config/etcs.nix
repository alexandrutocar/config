# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# etcs, everything else...
#
# ────────────────────────────────────────────────────────────────────────
{
  modulesPath,
  self,
  ...
}: {
  imports = [
    (self + "/etc/shared/01-settings/etcs.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    enableRedistributableFirmware = true;
    # TODO: Check what it does?
    # cpu.intel.updateMicrocode = true;
  };
}
