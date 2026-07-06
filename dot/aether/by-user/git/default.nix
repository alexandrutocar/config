# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █ ▀█▀ ▄▀ ▄▀█ ▀█▀ ▀▄ ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█
# █▄█ █ ░█░ ▀▄ █▀█ ░█░ ▄▀ █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./repositories;

  home = {
    homeDirectory = "/var/lib/git";
    stateVersion = "26.05";
    username = "git";
  };
}
