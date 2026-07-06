{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        description = mkForce "Administrator";

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
