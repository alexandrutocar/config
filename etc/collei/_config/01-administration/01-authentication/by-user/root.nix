{lib, ...}: let
  inherit (lib.modules) mkForce;
in let
  user.name = "root";
in {
  users = {
    users = {
      ${user.name} = {
        description = mkForce "Administrator";

        hashedPassword = "$y$j9T$3eE.gxBdQ1CZXo7/jgh1Q.$UE3bX81ROEFdMJp7Do9dY3zM9zjESMO3534YGasoXS8";
      };
    };
  };
}
