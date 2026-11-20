{lib, ...}: let
  inherit (lib.strings) concatStringsSep;
in {
  services = {
    forgejo = {
      settings = {
        server = {
          START_SSH_SERVER = false;
          SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
          MINIMUM_KEY_SIZE_CHECK = true;
        };

        "ssh.minimum_key_sizes" = {
          ED25519 = 256;
          ECDSA = 256;
          RSA = 3071; # some valid 3072-bit keys report 3071
          DSA = -1;
        };
      };
    };

    openssh = {
      enable = true;

      authorizedKeysInHomedir = false;

      hostKeys = [
        {
          type = "ed25519";
          path = "/etc/ssh/ssh_host_ed25519_key";
        }
      ];

      settings = {
        # Session/Forwarding
        # ------------------
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = "no";
        AllowStreamLocalForwarding = "no";
        PermitTunnel = "no";
        PermitUserEnvironment = false;
        GatewayPorts = "no";

        # Algorithms/Ciphers
        # ------------------
        KexAlgorithms = [
          "mlkem768x25519-sha256"
          "sntrup761x25519-sha512"
          "sntrup761x25519-sha512@openssh.com"
        ];
        Ciphers = [
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        HostKeyAlgorithms = concatStringsSep "," [
          "ssh-ed25519-cert-v01@openssh.com"
          "ssh-ed25519"
        ];
      };
    };
  };
}
