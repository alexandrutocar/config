# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  boot.initrd.systemd.emergencyAccess = "$y$j9T$mLfJsahjXgdzXWe4pzmt61$8jGIETsZydiqyCGeEec58hmiIQvS4neRj51IeVa10W5";

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
