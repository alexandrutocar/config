{config, ...}: let
  user.name = "root";
in {
  users.users = {
    ${user.name} = {
      extraGroups = [
        config.users.groups.ssh.name
      ];

      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfpJFgfixYN3d1NmHLvExsnemLdVJdBQugEJyLt5aLe alex@albedo"
        ];
      };
    };
  };
}
