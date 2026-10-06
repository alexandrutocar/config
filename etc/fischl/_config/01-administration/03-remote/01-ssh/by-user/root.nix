_: let
  user.name = "root";
in {
  users.users = {
    ${user.name} = {
      extraGroups = ["ssh"];

      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfpJFgfixYN3d1NmHLvExsnemLdVJdBQugEJyLt5aLe alex@albedo"
        ];
      };
    };
  };
}
