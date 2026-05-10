# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █ ▀█▀ ▄▀ ▄▀█ ▀█▀ ▀▄ ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█
# █▄█ █ ░█░ ▀▄ █▀█ ░█░ ▄▀ █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./01-repositories;

  home = {
    homeDirectory = "/var/lib/git";
    stateVersion = "25.11";
    username = "git";
  };
}
