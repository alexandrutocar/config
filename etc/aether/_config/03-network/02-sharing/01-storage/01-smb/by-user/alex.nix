_: let
  user.name = "alex";
in {
  users = {
    users = {
      ${user.name} = {
        isNormalUser = true;
        extraGroups = [
          "samba"
        ];
        hashedPasswordFile = "/etc/hashed/${user.name}";
      };
    };
  };

  services = {
    samba = {
      settings.${user.name} = {
        "path" = "/export/share/${user.name}";
        "public" = "no";

        "browsable" = "yes";
        "available" = "yes";
        "read only" = "no";

        "guest ok" = "no";

        "valid users" = [user.name];

        "create mask" = "0660";
        "directory mask" = "2750";
        "force directory mode" = "2770";

        "vfs objects" = "catia fruit streams_xattr";
      };
    };
  };
}
