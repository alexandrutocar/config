# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █▀▀ █▀ █▄▀ ▀█▀ █▀█ █▀█
# █▄▀ ██▄ ▄█ █░█ ░█░ █▄█ █▀▀
#
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
#
# compositor, display, keybindings, notifications,
# wallpaper, scripts...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (pkgs.custom.scripts.extras) backup pools;
in {
  imports = singleton (self + /dot/shared/settings/desktop-environment.nix);

  wayland.windowManager.river = {
    settings = {
      rule-add = {
        # Anki
        # ----
        "-app-id"."'anki'"."-title"."'Add'" = "float";
        "-app-id"."'anki'"."-title"."'Browse *'" = "float";

        # Evolution
        # ---------
        "-app-id"."'org.gnome.Evolution'"."-title"."'*'" = "float";
        "-app-id"."'org.gnome.Evolution'"."-title"."'Eingang*'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Kontakte'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Kalendar'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Aufgaben'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Notizen'" = ["no-float"];

        "-app-id"."'evolution-alarm-notify'"."-title"."'*'" = ["float"];

        # Zathura
        # -------
        "-app-id"."'org.pwmt.zathura'" = ["ssd" "float"];
      };

      map.normal = {
        # Super+B to start a  guide
        "Super B" = "spawn '${getExe backup}'";

        # Super+P to start a new connection to the computer pool
        "Super P" = "spawn '${getExe pools}'";
      };
    };
  };
}
