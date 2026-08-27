# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + "/etc/shared/01-settings/systemd.nix");

  # in case of a configuration early in the boot sequence,
  # allow entering emergency shell (helps with debugging)
  boot.initrd.systemd.emergencyAccess = "$y$j9T$mLfJsahjXgdzXWe4pzmt61$8jGIETsZydiqyCGeEec58hmiIQvS4neRj51IeVa10W5";

  environment.persistence."/state" = {
    directories = [
      "/var/lib/systemd"

      # journal should stay between reboots
      # for auditing purposes
      "/var/log/journal"
    ];
  };

  # MACHINE-ID
  # ----------
  environment.etc.machine-id.source = "/state/etc/machine-id";
}
