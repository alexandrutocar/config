# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █▄▄ █▀▀ █▀▄ █▀█ ░░▄▀ ▄▀█ █░░ █▀▀ ▀▄▀
# █▀█ █▄▄ █▄█ ██▄ █▄▀ █▄█ ▄▀░░ █▀█ █▄▄ ██▄ █░█
#
# alex@albedo
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./programs ++ recursive ./settings;

  home = {
    homeDirectory = "/home/alex";
    stateVersion = "25.11";
    username = "alex";
  };
}
