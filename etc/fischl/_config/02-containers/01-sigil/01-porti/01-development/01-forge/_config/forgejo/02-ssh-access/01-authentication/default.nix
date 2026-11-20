{lib, ...}: let
  inherit (lib.strings) concatStringsSep;
in let
  allowedGroup = "ssh";
in {
  users = {
    groups = {
      ${allowedGroup} = {};
    };
  };

  services = {
    openssh = {
      settings = {
        AuthenticationMethods = "publickey";
        UsePAM = true;
        AllowGroups = [allowedGroup];
        PubkeyAuthentication = true;

        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;

        PermitRootLogin = "no";
        PermitEmptyPasswords = false;

        PubkeyAcceptedAlgorithms = concatStringsSep "," [
          "ssh-ed25519"
          "sk-ssh-ed25519@openssh.com"
          "ecdsa-sha2-nistp256"
          "ecdsa-sha2-nistp384"
          "ecdsa-sha2-nistp521"
          "sk-ecdsa-sha2-nistp256@openssh.com"
          "rsa-sha2-512"
          "rsa-sha2-256"
        ];
      };
    };
  };
}
