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
  imports = singleton (self + /etc/shared/settings/administration.nix);

  users = {
    users = {
      alex = {
        isNormalUser = true;

        extraGroups = [
          "libvirtd"
          "docker"
          "wheel"
          "netdev"
          "scanner"
          "wireshark"
        ];

        hashedPasswordFile = "/state/etc/hashed/alex";
      };

      root = {
        hashedPassword = "$y$j9T$7EFJ/2c8Rs8GpVxYSdeFp.$0oL/c7OO91PW5nQk0aRRs9Ar8ogpsVTn.QFbQYVuD95";
      };
    };
  };

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
    files = [
      # Secure Shell' Host Keys
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };
}
