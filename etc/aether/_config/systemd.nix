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
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/systemd.nix");

  boot.initrd.systemd.emergencyAccess = "$y$j9T$/wz/tR9.fA4bxAhxqDwtU1$F88.5ajoPgSryf8FUODs.nu1kNwyin3pTUruSE.ahI6";

  environment = {
    etc.machine-id.source = "/state/etc/machine-id";

    persistence = {
      "/state" = {
        directories = [
          "/var/lib/systemd"
          "/var/log/journal"
        ];
      };
    };
  };
}
