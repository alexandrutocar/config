{config, ...}: let
  user.name = "builder";
in {
  users.users = {
    ${user.name} = {
      extraGroups = [
        config.users.groups.ssh.name
      ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItoIVV/KQYI9MUdJpnLxVT9wRsxSjpAg2gQUxmfJCak alex@albedo"
      ];
    };
  };
}
