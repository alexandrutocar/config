{
  config,
  pkgs,
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

  environment.etc."ssh/forgejo-keys" = {
    mode = "0755";
    text = ''
      #!${pkgs.runtimeShell}
      exec ${getExe config.services.forgejo.package} \
        --config ${config.services.forgejo.customDir}/conf/app.ini \
        keys "$@"
    '';
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
          AuthorizedKeysCommand /etc/${config.environment.etc."ssh/forgejo-keys".target} -u %u -t %t -k %k
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
