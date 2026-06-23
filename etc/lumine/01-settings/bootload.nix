# ────────────────────────────────────────────────────────────────────────
#
# █▄▄ █▀█ █▀█ ▀█▀ █░░ █▀█ ▄▀█ █▀▄
# █▄█ █▄█ █▄█ ░█░ █▄▄ █▄█ █▀█ █▄▀
#
# bootloader, secure boot...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkForce;
in {
  # BOOTLOADER
  # ----------

  # NOTE: Hetzner uses BIOS (legacy) boot.
  boot.loader.systemd-boot.enable = mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_116491725";
    efiSupport = false;
  };
  boot.kernelParams = ["boot.shell_on_fail"];
}
