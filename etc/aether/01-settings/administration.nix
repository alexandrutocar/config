# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▄ █▀▄▀█ █ █▄░█ █ █▀ ▀█▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █▄▀ █░▀░█ █ █░▀█ █ ▄█ ░█░ █▀▄ █▀█ ░█░ █ █▄█ █░▀█
#
# system users, security policies, and early boot emergency access...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkMerge;
in {
  imports = singleton (self + /etc/shared/01-settings/administration.nix);

  users.groups = {
    builder = {};
    cache = {};
    git = {};
  };

  users.users = mkMerge [
    {
      builder = {
        group = "builder";

        isNormalUser = true;

        openssh = {
          authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItoIVV/KQYI9MUdJpnLxVT9wRsxSjpAg2gQUxmfJCak alex@albedo"
          ];
        };
      };

      cache = {
        group = "cache";

        isNormalUser = true;

        openssh = {
          authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUn9Mp/Jj1cPjZuc/PuLOJN8Kcu8QybIzWeC4KcxaMQ alex@albedo"
          ];
        };
      };

      git = {
        home = "/var/lib/git";
        group = "git";

        isSystemUser = true;

        openssh = {
          authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+Hv86vvA3XpfouF6a2w84MRIjTZVHfGZsOzbpEG6K5 alex@albedo"
          ];
        };

        shell = getExe' pkgs.git "git-shell";
      };
    }
    {
      root = {
        openssh = {
          authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0Hozax7+poMyiZ/CNOalddizu6x/mhMZd/TThnCFQ4 alex@albedo"
          ];
        };

        hashedPasswordFile = "/etc/hashed/root";
      };
    }
  ];

  services = {
    # SECURE SHELL ACCESS
    # -------------------
    openssh = {
      enable = true;
      settings = {
        Banner = "/state/etc/ssh/banner";
      };

      extraConfig = let
        algorithms = {
          key = [
            "ssh-ed25519-cert-v01@openssh.com"
            "ssh-ed25519"
            "ssh-rsa-cert-v01@openssh.com"
            "ssh-rsa"
          ];
          kex = [
            "sntrup761x25519-sha512"
            "mlkem768x25519-sha256"
          ];
          mac = [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
          ];
          enc = [
            "aes256-gcm@openssh.com"
            "aes128-gcm@openssh.com"
          ];
        };
      in ''
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Figure out which addresses to listen on.
        # - Take onion-proxy into account.
        # ────────────────────────────────────────────────────────────────────────
        # ListenAddress 127.0.0.1:22
        Protocol 2
        # Banner (handled in options)

        # Authentication
        PubkeyAuthentication yes
        UsePAM yes

        # ────────────────────────────────────────────────────────────────────────
        # TODO: Add relevant users to the ssh-allowed group.
        # ────────────────────────────────────────────────────────────────────────
        # AllowGroups ssh-user

        PasswordAuthentication no
        ChallengeResponseAuthentication no

        # Limit Algorithms and Ciphers
        KexAlgorithms ${builtins.concatStringsSep "," algorithms.kex}
        MACs ${builtins.concatStringsSep "," algorithms.mac}
        Ciphers ${builtins.concatStringsSep "," algorithms.enc}
        HostKeyAlgorithms ${builtins.concatStringsSep "," algorithms.key}

        Match user git
          AllowTcpForwarding no
          AllowAgentForwarding no
          PasswordAuthentication no
          PermitTTY no
          X11Forwarding no

        Match user cache
          AllowTcpForwarding no
          AllowAgentForwarding no
          PasswordAuthentication no
          PermitTTY no
          X11Forwarding no
      '';

      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
          rounds = 200;
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
          rounds = 200;
        }
      ];
    };

    # FAIL2BAN
    # --------
    fail2ban = {
      enable = true;
      bantime = "24h";
      maxretry = 3;

      bantime-increment = {
        enable = true;
        rndtime = "8m";
      };
    };

    # ONION SERVICE (SSH)
    # -------------------
    tor = {
      # ────────────────────────────────────────────────────────────────────────
      # TODO: Make accessible over Tor network.
      # ────────────────────────────────────────────────────────────────────────
      enable = false;

      relay.onionServices = {
        ssh = {
          authorizedClients = [
            "descriptor:x25519:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
          ];
          settings = {
          };
          map = [
            22
          ];
        };
      };
    };
  };

  environment.persistence."/state" = {
    directories = [
      "/var/lib/git"
      "/etc/hashed"
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
