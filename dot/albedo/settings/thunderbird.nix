# ────────────────────────────────────────────────────────────────────────
#
# ▀█▀ █░█ █░█ █▄░█ █▀▄ █▀▀ █▀█ █▄▄ █ █▀█ █▀▄
# ░█░ █▀█ █▄█ █░▀█ █▄▀ ██▄ █▀▄ █▄█ █ █▀▄ █▄▀
#
# thunderbird, connections, calendars, contacts,
# mail, extensions...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  programs.thunderbird = {
    enable = true;

    profiles = {
      Personal = {
        isDefault = true;
        settings = {
          "mail.openpgp.allow_external_gnupg" = true;
        };
      };
    };
  };

  wayland.windowManager.river.settings = {
    rule-add = {
      "-app-id"."'thunderbird'" = "float";
    };
  };

  home.packages = with pkgs; [
    gpgme
  ];
}
