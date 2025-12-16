# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▄█ █▀ ▀█▀ █▀▀ █▀▄▀█ █▀▄
# ▄█ ░█░ ▄█ ░█░ ██▄ █░▀░█ █▄▀
#
# systemd, logs...
#
# ────────────────────────────────────────────────────────────────────────
_: {
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
