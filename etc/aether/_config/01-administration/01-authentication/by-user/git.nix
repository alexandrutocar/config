{
  config,
  pkgs,
  lib,
  ...
}: let
  user.name = "git";
in {
  users = {
    groups.${config.users.users.${user.name}.group} = {};

    users = {
      ${user.name} = let
        inherit (lib.attrsets) getBin;
      in {
        isSystemUser = true;

        group = user.name;

        home = "/var/lib/${user.name}";

        shell = with pkgs; getBin git + git.shellPath;
      };
    };
  };

  environment.persistence = {
    "/state" = {
      directories = [
        config.users.users.${user.name}.home
      ];
    };
  };
}
