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
  imports = recursive (self + /dot/shared/1-applications) ++ (recursive ./1-applications) ++ recursive (self + /dot/shared/2-desktop) ++ (recursive ./2-desktop) ++ recursive (self + /dot/shared/3-shortcuts) ++ (recursive ./3-shortcuts);

  home = {
    homeDirectory = "/home/alex";
    stateVersion = "25.11";
    username = "alex";
  };
}
