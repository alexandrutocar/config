_: let
  user.name = "root";
in {
  users.users = {
    ${user.name} = {
      extraGroups = ["ssh"];

      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFqc9UHouDJ8CKLFYUNteH3WX7FskQouDeW/S+xeks7 alex@albedo"
        ];
      };
    };
  };
}
