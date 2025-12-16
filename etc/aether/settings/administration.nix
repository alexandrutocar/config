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
in {
  imports = singleton (self + /etc/shared/settings/administration.nix);

  # in case of a configuration early in the boot sequence,
  # allow entering emergency shell (helps with debugging)
  boot.initrd.systemd.emergencyAccess = "$y$j9T$/wz/tR9.fA4bxAhxqDwtU1$F88.5ajoPgSryf8FUODs.nu1kNwyin3pTUruSE.ahI6";

  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0Hozax7+poMyiZ/CNOalddizu6x/mhMZd/TThnCFQ4 alex"
      ];

      hashedPasswordFile = "/etc/hashed/root";
    };

    git = {
      isSystemUser = true;
      group = "git";
      home = "/var/lib/git";
      createHome = true;
      shell = getExe' pkgs.git "git-shell";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFoDa2D88CGPbiMvQ1SCsEffhLIFGbOtINHpQjXi+vNX alex"
      ];
    };
  };

  users.groups.git = {};

  services = {
    # SECURE SHELL ACCESS
    # -------------------
    openssh = {
      enable = true;
      banner = ''
               ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⠤⢤⣀
        ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠴⠒⢋⣉⣀⣠⣄⣀⣈⡇
        ⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⣯⠴⠚⠉⠉⠀⠀⠀⠀⣤⠏⣿
        ⡇⠁⠀⠀⠀⠀⡄⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⡿⠿⢛⠁⠁⣸⠀⠀⠀⠀⠀⣤⣾⠵⠚⠁
        ⢧⠀⠀⢀⣠⡾⡇⠀⠀⠀⠀⠀⣠⣴⠿⠋⠁⠀⠀⠀⠀⠘⣿⠀⣀⡠⠞⠛⠁⠂⠁
        ⠸⣄⣡⢾⡿⠁⠀⠀⠀⣀⣴⠟⠋⠁⠀⠀⠀⠀⠐⠠⡤⣾⣙⣶⡶⠃
        ⣖⣾⡷⢿⣐⣀⣀⣤⢾⣋⠁⠀⠀⠀⣀⢀⣀⣀⣀⣀⠀⢀⢿⠑⠃
        ⣿⣿⢾⠶⣧⡼⢏⠑⠚⠋⠉⠉⡉⡉⠉⠉⠹⠈⠁⠉⠀⠨⢾⡂
        ⣟⣇⣷⣞⡛⠁
        ⣿⠟⠙⣧⠅⡄⠀⠀⠀⠀⠀⠀⠰⡆⠀⠀⠀⠀⢠⣾⡄
        ⡾⡒⠖⠉⠏⠁⠀⠀⠀⠀⣀⢀⣠⣧⣀⣀⠀⠀⠀⠚
        ⡏⠅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⣿⢭⠉
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠂⢿⠘
      '';
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
