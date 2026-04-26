# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀ █▀ █▀▀ █▄░█ ▀█▀ █ ▄▀█ █░░ █▀
# ██▄ ▄█ ▄█ ██▄ █░▀█ ░█░ █ █▀█ █▄▄ ▄█
#
# essential applications, programs ...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /dot/shared/settings/essentials.nix);

  home.packages = with pkgs; [
    # PASSWORD MANAGERS
    # -----------------
    (pass.withExtensions (extensions:
      with extensions; [
        pass-tomb
        pass-file
      ]))
  ];
}
