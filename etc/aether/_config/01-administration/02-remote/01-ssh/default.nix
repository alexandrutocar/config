_: {
  environment.persistence = {
    "/state" = {
      files = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };
  };

  services.openssh = {
    enable = true;

    settings = {
      # General
      Protocol = 2;

      Banner = "/state/etc/ssh/banner";

      # Authentication
      PubkeyAuthentication = true;
      UsePAM = true;
      AllowGroups = ["ssh"];
      PasswordAuthentication = false;
      ChallengeResponseAuthentication = false;

      # Algorithms and Ciphers
      HostKeyAlgorithms = builtins.concatStringsSep "," [
        "ssh-ed25519-cert-v01@openssh.com"
        "ssh-ed25519"
        "ssh-rsa-cert-v01@openssh.com"
        "ssh-rsa"
      ];

      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];

      Ciphers = [
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];

      KexAlgorithms = [
        "sntrup761x25519-sha512"
        "mlkem768x25519-sha256"
      ];
    };
  };

  users.groups = {
    ssh = {};
  };
}
