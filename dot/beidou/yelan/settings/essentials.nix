# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀ █▀ █▀▀ █▄░█ ▀█▀ █ ▄▀█ █░░ █▀
# ██▄ ▄█ ▄█ ██▄ █░▀█ ░█░ █ █▀█ █▄▄ ▄█
#
# applications, fonts...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive (self + /dot/shared/settings/essentials);

  home.packages = with pkgs; [
    # MARKDOWN VIEWER
    # ---------------
    glow
  ];
}
