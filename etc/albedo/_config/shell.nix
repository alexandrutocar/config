# ────────────────────────────────────────────────────────────────────────
#
# █▀ █░█ █▀▀ █░░ █░░
# ▄█ █▀█ ██▄ █▄▄ █▄▄
#
# shell, terminal, utilities...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkMerge;
in {
  imports = singleton (self + "/etc/shared/01-settings/shell.nix");

  environment.systemPackages = with pkgs; [
    comma
  ];

  programs = {
    # SECURE SHELL
    # ------------
    ssh = {
      hosts = let
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
            "curve25519-sha256"
            "diffie-hellman-group-exchange-sha256"
          ];
          mac = [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
            # "umac-128-etm@openssh.com"
          ];
          enc = [
            # "chacha20-poly1305@openssh.com"
            "aes256-gcm@openssh.com"
            "aes128-gcm@openssh.com"
          ];
        };
      in {
        "*" = mkMerge [
          {
            order = 0;
          }
          {
            # Allow (Strictly) Public Key Authentication
            PubkeyAuthentication = true;

            # Restrict Authentication Methods
            ChallengeResponseAuthentication = false;
            PasswordAuthentication = false;

            # Limit Algorithms and Ciphers
            KexAlgorithms = builtins.concatStringsSep "," algorithms.kex;
            MACs = builtins.concatStringsSep "," algorithms.mac;
            Ciphers = builtins.concatStringsSep "," algorithms.enc;
            HostKeyAlgorithms = builtins.concatStringsSep "," algorithms.key;

            # Disable Agent Forwarding
            ForwardAgent = false;
            ForwardX11 = false;

            # Strict Host-Key Checking
            StrictHostKeyChecking = "ask";

            # Reduce Connection Attack Surface
            ServerAliveInterval = 60;
            ServerAliveCountMax = 3;
          }
        ];
        "*.onion" = mkMerge [
          {
            order = 1;
          }
          {
            ProxyCommand = "${pkgs.socat}/bin/socat - SOCKS4A:localhost:%h:%p,socksport=9050";
          }
        ];
      };
    };

    # NIX INDEX
    # ---------
    nix-index = {
      enable = true;
    };
  };
}
