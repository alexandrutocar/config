{config, ...}: let
  user.name = "cache";
in {
  users = {
    groups.${config.users.users.${user.name}.group} = {};

    users = {
      ${user.name} = {
        isNormalUser = true;

        group = user.name;
      };
    };
  };
}
