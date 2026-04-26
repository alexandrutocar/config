# ────────────────────────────────────────────────────────────────────────
#
# █▄▄ █▀▀ █ █▀▄ █▀█ █░█ ░░▄▀ ▄▀█ █░░ █▀▀ ▀▄▀
# █▄█ ██▄ █ █▄▀ █▄█ █▄█ ▄▀░░ █▀█ █▄▄ ██▄ █░█
#
# alex@aether
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./settings;

  home = {
    homeDirectory = "/home/yelan";
    stateVersion = "25.11";
    username = "yelan";
  };
}
