# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▄ █▀▄▀█ █ █▄░█ █ █▀ ▀█▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █▄▀ █░▀░█ █ █░▀█ █ ▄█ ░█░ █▀▄ █▀█ ░█░ █ █▄█ █░▀█
#
# system users, security policies...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in {
  imports = singleton (self + /etc/shared/settings/administration.nix);

  services.getty.autologinUser = mkForce "alex";

  users.users = {
    alex = {
      isNormalUser = true;
      extraGroups = ["wheel" "video"];
      initialHashedPassword = "";
    };
    root.initialHashedPassword = "";
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

  security = {
    pam.services.lightdm.text = ''
      auth sufficient pam_succeed_if.so user ingroup wheel
    '';
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
