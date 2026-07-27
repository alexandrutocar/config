_: let
  user.name = "root";
in {
  users.users = {
    ${user.name} = {
      extraGroups = ["ssh"];

      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0Hozax7+poMyiZ/CNOalddizu6x/mhMZd/TThnCFQ4 alex@albedo"
        ];
      };
    };
  };
}
