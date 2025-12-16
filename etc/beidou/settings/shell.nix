# ────────────────────────────────────────────────────────────────────────
#
# █▀ █░█ █▀▀ █░░ █░░
# ▄█ █▀█ ██▄ █▄▄ █▄▄
#
# shell, privacy guard, terminal, utilities ...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) pinentry-curses;
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/settings/shell.nix);

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pinentry-curses;
    enableSSHSupport = true;

    settings = {
      ttyname = "$GPG_TTY";
      default-cache-ttl = 60;
      max-cache-ttl = 120;
    };
  };
}
