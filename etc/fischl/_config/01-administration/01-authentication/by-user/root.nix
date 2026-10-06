{lib, ...}: let
  inherit (lib.modules) mkForce;
in let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        description = mkForce "Administrator";

        hashedPasswordFile = "/state/etc/hashed/${user.name}";
      };
    };
  };
}
