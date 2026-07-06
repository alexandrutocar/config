{config, ...}: let
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
