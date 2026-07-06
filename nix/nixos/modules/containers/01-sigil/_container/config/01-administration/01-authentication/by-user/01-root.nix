{lib, ...}: let
  inherit (lib.modules) mkOverride;
in let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        initialHashedPassword = mkOverride 150 "";
      };
    };
  };
}
