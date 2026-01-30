# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▄▀█ █░█ ▄▀█
# █▀░ █▀█ ▀▄▀ █▀█
#
# fava, beancount, web-interface...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self;
in {
  users.users.fava0 = {
    uid = 1000; # Match host UID
    group = "users";
    isSystemUser = true;
  };

  services.fava = {
    enable = true;
    settings = {
      host = self.address;
      port = 8080;
      bean = "transactions.bean";
    };

    # Needed to match Samba's permissions.
    user = "fava0";
    group = "users";
  };
}
