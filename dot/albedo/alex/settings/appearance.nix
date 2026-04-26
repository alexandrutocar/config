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
  inherit (pkgs.custom.scripts.extras) pools;
in {
  imports = singleton (self + /dot/shared/settings/desktop-environment.nix);

  wayland.windowManager.river = {
    settings = {
      rule-add = {
        # Evolution
        # ---------
        "-app-id"."'org.gnome.Evolution'"."-title"."'*'" = "float";
        "-app-id"."'org.gnome.Evolution'"."-title"."'Eingang*'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Kontakte'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Kalendar'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Aufgaben'" = ["no-float"];
        "-app-id"."'org.gnome.Evolution'"."-title"."'Notizen'" = ["no-float"];

        "-app-id"."'evolution-alarm-notify'"."-title"."'*'" = ["float"];
      };

      map.normal = {
        # Super+P to start a new connection to the computer pool
        "Super P" = "spawn '${getExe pools}'";
      };
    };
  };
}
