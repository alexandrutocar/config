# ────────────────────────────────────────────────────────────────────────
#
# █▀▄▀█ █ █▄░█ █ █▀▀ █░░ █░█ ▀▄▀
# █░▀░█ █ █░▀█ █ █▀░ █▄▄ █▄█ █░█
#
# miniflux, feed reader...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self x0-pgl;
in {
  services.miniflux = {
    enable = true;

    settings = {
      CREATE_ADMIN = 1;

      PORT = 8080;

      ADMIN_PASSWORD_FILE = "/var/lib/miniflux/admin/password.txt";
      ADMIN_USERNAME_FILE = "/var/lib/miniflux/admin/username.txt";

      LISTEN_ADDR = self.address;
      DATABASE_URL = "dbname=miniflux user=miniflux host=${x0-pgl.address} sslmode=disable";
    };
  };
}
