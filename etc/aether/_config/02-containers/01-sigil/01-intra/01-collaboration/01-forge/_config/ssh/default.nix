{
  config,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in {
  networking = {
    firewall = {
      allowedTCPPorts = config.services.openssh.ports;
    };
  };

  security = {
    wrappers = {
      forgejo = {
        source = getExe config.services.forgejo.package;
        owner = "root";
        group = "root";
        permissions = "u+rx,g+rx,o+rx";
      };
    };
  };

  users = {
    groups = {
      ssh = {};
    };
  };

  services = {
    openssh = {
      enable = true;

      extraConfig = ''
        Match User git
          AuthorizedKeysCommand /run/wrappers/bin/forgejo --config ${config.services.forgejo.customDir}/conf/app.ini keys -u %u -t %t -k %k
          AuthorizedKeysCommandUser git
      '';

      settings = {
        # Authentication
        PubkeyAuthentication = true;
        UsePAM = true;
        AllowGroups = ["ssh"];
        PasswordAuthentication = false;
        ChallengeResponseAuthentication = false;

        # General
        Protocol = 2;

        # Algorithms and Ciphers

        KexAlgorithms = [
          "sntrup761x25519-sha512"
          "mlkem768x25519-sha256"
        ];
        Ciphers = [
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
        ];

        HostKeyAlgorithms = builtins.concatStringsSep "," [
          "ssh-ed25519-cert-v01@openssh.com"
          "ssh-ed25519"
          "ssh-rsa-cert-v01@openssh.com"
          "ssh-rsa"
        ];
      };
    };
  };
}
