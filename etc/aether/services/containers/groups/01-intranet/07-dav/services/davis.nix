# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ ▄▀█ █░█ █ █▀
# █▄▀ █▀█ ▀▄▀ █ ▄█
#
# davis, dav, calendar, addresses, contacts...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self intranet-database;
in {
  services.davis = {
    enable = true;

    settings = {
      # General
      APP_ENV = "prod";
      # ────────────────────────────────────────────────────────────────────────
      # TAGS: #!security
      # TODO: Renew and set with SetCredentialEncryption.
      # ────────────────────────────────────────────────────────────────────────
      # cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w 48 | head -n 1
      APP_SECRET = "XC1Z10J2Bxru2brX7KgijbWjBal6hHqcagCi4z3A8jhWxFjd";

      # Storage
      DATABASE_DRIVER = "pgsql";
      DATABASE_URL = "pgsql://davis@${intranet-database.localAddress}:5432/davis?sslmode=disable";

      # Storage (SQLite)
      # DATABASE_DRIVER = "sqlite";
      # DATABASE_URL = builtins.concatStringsSep "/" ["sqlite://" config.services.davis.dataDir "davis.db"];

      # Calendar
      CALDAV_ENABLED = "true";
      INVITE_FROM_ADDRESS = "no-reply@aether.ip";
      PUBLIC_CALENDARS_ENABLED = "true";

      # Contacts
      CARDDAV_ENABLED = "true";
      BIRTHDAY_REMINDER_OFFSET = "PT9H";

      # Initial Admin
      ADMIN_LOGIN = "admin";
      ADMIN_PASSWORD = "admin";
    };

    nginx = {
      listen = [
        {
          addr = self.localAddress;
          port = 8080;
        }
      ];
    };
  };
}
