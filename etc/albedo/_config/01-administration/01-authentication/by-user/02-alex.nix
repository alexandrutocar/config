_: let
  user.name = "alex";
in {
  users = {
    users = {
      ${user.name} = {
        isNormalUser = true;

        extraGroups = [
          "libvirtd"
          "docker"
          "wheel"
          "netdev"
          "scanner"
          "wireshark"
        ];

        hashedPasswordFile = "/state/etc/hashed/${user.name}";
      };
    };
  };
}
