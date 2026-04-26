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
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /dot/shared/settings/essentials.nix);

  home.packages = [
    # MARKDOWN VIEWER
    # ---------------
    glow
  ];
}
