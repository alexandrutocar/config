# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  boot.initrd.systemd.emergencyAccess = "$y$j9T$MhPQKIiB8ZyByVmC1jbtg1$gp1KSpvG3K0V4CaBaihO2woUNK65JuiijLFuf1mMt4A";

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
