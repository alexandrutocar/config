_: let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        hashedPasswordFile = "/state/etc/hashed/${user.name}";
      };
    };
  };
}
