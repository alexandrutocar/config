# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █▄▄ █▀▀ █▀▄ █▀█ ░░▄▀ ▄▀█ █░░ █▀▀ ▀▄▀
# █▀█ █▄▄ █▄█ ██▄ █▄▀ █▄█ ▄▀░░ █▀█ █▄▄ ██▄ █░█
#
# alex@albedo
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive (self + "/dot/shared/01-applications") ++ (recursive ./01-applications) ++ recursive (self + "/dot/shared/02-desktop") ++ (recursive ./02-desktop) ++ recursive (self + "/dot/shared/03-shortcuts") ++ (recursive ./03-shortcuts);

  home = {
    homeDirectory = "/home/alex";
    stateVersion = "26.05";
    username = "alex";
  };
}
