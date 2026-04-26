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
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive (self + /dot/shared/settings/essentials);

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
