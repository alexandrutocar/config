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
in {
  imports = singleton (self + /etc/shared/settings/shell.nix);

  # SECURE SHELL
  # ------------
  programs.ssh = {
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
          "curve25519-sha256"
          # ────────────────────────────────────────────────────────────────────────
          # TODO: Remove when "login-stud.informatik.uni-bonn.de" gets updated.
          # ────────────────────────────────────────────────────────────────────────
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
    in ''
      Host *
        # Allow (Strictly) Public Key Authentication
        PubkeyAuthentication yes

        # Restrict Authentication Methods
        ChallengeResponseAuthentication no
        PasswordAuthentication no

        # Limit Algorithms and Ciphers
        KexAlgorithms ${builtins.concatStringsSep "," algorithms.kex}
        MACs ${builtins.concatStringsSep "," algorithms.mac}
        Ciphers ${builtins.concatStringsSep "," algorithms.enc}
        HostKeyAlgorithms ${builtins.concatStringsSep "," algorithms.key}

        # Disable Agent Forwarding
        ForwardAgent no
        ForwardX11 no

        # Strict Host-Key Checking
        StrictHostKeyChecking ask
        UserKnownHostsFile ~/.ssh/known_hosts

        # Reduce Connection Attack Surface
        ServerAliveInterval 60
        ServerAliveCountMax 3

      Host *.onion
        ProxyCommand ${pkgs.socat}/bin/socat - SOCKS4A:localhost:%h:%p,socksport=9050
    '';
  };
}
