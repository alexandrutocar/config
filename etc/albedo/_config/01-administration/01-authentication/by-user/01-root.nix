{config, ...}: let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        hashedPasswordFile = "/etc/hashed/${user.name}";
      };
    };
  };

  environment.persistence = {
    "/state" = {
      files = [
        config.users.users.${user.name}.hashedPasswordFile
      ];
    };
  };
}
