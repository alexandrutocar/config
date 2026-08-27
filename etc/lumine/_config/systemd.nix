# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  boot.initrd.systemd.emergencyAccess = "$y$j9T$yeh5/LtwJ2TFszguix91K1$q6TuCHI2RzfPeSfo0P2I7VUiMM9ImzHLVunUfaL.mxD";

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
