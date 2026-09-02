# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▄ █▀▄▀█ █ █▄░█ █ █▀ ▀█▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █▄▀ █░▀░█ █ █░▀█ █ ▄█ ░█░ █▀▄ █▀█ ░█░ █ █▄█ █░▀█
#
# system users, security policies, and early boot emergency access...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + "/etc/shared/01-settings/administration.nix");

  # PAM
  # ---
  security.pam.services = {
    waylock = {
      text = "auth include login";
    };
  };

  # SMART CARDS
  # -----------------------------
  hardware.gpgSmartcards.enable = true;
  services.pcscd.enable = true;

  # GNU PRIVACY GUARD
  # -----------------
  programs.gnupg.agent = {
    enable = true;
    enableBrowserSocket = true;

    settings = {
      ttyname = "$GPG_TTY";
      default-cache-ttl = 60;
      max-cache-ttl = 120;
    };
  };

  environment.persistence."/state" = {
    directories = [
      "/var/lib/nixos"
    ];
  };
}
