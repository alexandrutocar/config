# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs, nspawn, firewall, network-address-translation (nat)...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + /etc/shared/settings/systemd.nix);

  # in case of a configuration early in the boot sequence,
  # allow entering emergency shell (helps with debugging)
  boot.initrd.systemd.emergencyAccess = "$y$j9T$/wz/tR9.fA4bxAhxqDwtU1$F88.5ajoPgSryf8FUODs.nu1kNwyin3pTUruSE.ahI6";

  environment.persistence."/state" = {
    directories = [
      "/var/lib/systemd"

      # journal should stay between reboots
      # for auditing purposes
      "/var/log/journal"
    ];
    files = [
      "/etc/machine-id"
    ];
  };
}
