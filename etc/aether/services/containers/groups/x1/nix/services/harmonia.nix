# ────────────────────────────────────────────────────────────────────────
#
# █░█ ▄▀█ █▀█ █▀▄▀█ █▀█ █▄░█ █ ▄▀█
# █▀█ █▀█ █▀▄ █░▀░█ █▄█ █░▀█ █ █▀█
#
# harmonia, binary cache...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self;
in {
  services.harmonia-dev = {
    cache = {
      enable = true;

      settings = {
        bind = "${self.address}:8080";

        workers = 1;

        priority = 50;

        max_connection_rate = 16;
      };

      signKeyPaths = [
        "/var/lib/harmonia/cache.ueuie.dev.key"
      ];
    };

    daemon.enable = true;
  };
}
