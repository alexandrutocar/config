# ────────────────────────────────────────────────────────────────────────
#
# █▀▄▀█ █ █▄░█ █ █▀▀ █░░ █░█ ▀▄▀
# █░▀░█ █ █░▀█ █ █▀░ █▄▄ █▄█ █░█
#
# miniflux, rss reader...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self intranet-database;
in {
  services.miniflux = {
    enable = true;

    settings = {
      CREATE_ADMIN = 1;

      PORT = 8080;

      ADMIN_PASSWORD_FILE = "/var/lib/miniflux/admin/password.txt";
      ADMIN_USERNAME_FILE = "/var/lib/miniflux/admin/username.txt";

      LISTEN_ADDR = self.localAddress;
      DATABASE_URL = "dbname=miniflux user=miniflux host=${intranet-database.localAddress} sslmode=disable";
    };
  };
}
