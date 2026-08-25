{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
  inherit (lib.modules) mkMerge;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.pocket-id.settings.PORT # HTTP
      ];
    };
  };

  systemd = {
    services = {
      pocket-id = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=encryption_key - -
            "encryption_key" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACVUx3OHzQgUsoxK6AAAAAAsoBQoqEdV9jUzOu
              nz5gfXij4i9MOSjW4GJ0Jlqm1Tm27NPmpHkDR/EXDmk5fIZsjMxeDJeKqFF++D4vJxmmwfVSvA0vbbq
              PbpaC/4WUYYxlUU0G0iP8bBMqOwkRKf2gR502F88wOGT9MakCsKO27EiWZfHzZDjx8
            '';
            # echo -n "<password>" | systemd-creds encrypt --with-key=host --name=ldap_bind_dn_password - -
            "ldap_bind_dn_password" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAA+MNM67vdTZcM5OpEAAAAATBAKukgW9DkyZkZ
              WI/E9p0v7ivegnbB7Mz6Dme0kQ/f9PfB4/ZOUc1U4+y+mpGOyZbRagBYb1tXBsd6h9BwKNhLXYdKuZz
              RpYTNx6YAXYoeUjjkj3iZtFyDO+ab67adZ
            '';
          };
        };
      };
    };
  };

  services.pocket-id = {
    enable = true;

    settings = mkMerge [
      # Telemetry
      {
        VERSION_CHECK_DISABLED = true;
        ANALYTICS_DISABLED = true;
      }
      # Security
      {
        ALLOW_INSECURE_CALLBACK_URLS = false;
      }
      # Server
      {
        HOST = sigil.self.addresses.ula;
        PORT = 8081;
      }
      # Service
      {
        ENCRYPTION_KEY_FILE = "/run/credentials/pocket-id.service/encryption_key";

        APP_URL = "https://pocket-id.intra.net.internal";

        UI_CONFIG_DISABLED = true;
      }
      # Directory
      {
        LDAP_ENABLED = true;

        LDAP_URL = "ldap://[::1]:3890";

        LDAP_BASE = "dc=intra,dc=net,dc=internal";
        LDAP_BIND_DN = "cn=pocket-id,ou=people,dc=intra,dc=net,dc=internal";
        LDAP_BIND_PASSWORD_FILE = "/run/credentials/pocket-id.service/ldap_bind_dn_password";

        # Filters
        LDAP_USER_SEARCH_FILTER = "(&(objectClass=person)(!(memberOf=cn=service,ou=groups,dc=intra,dc=net,dc=internal)))";

        # Map
        LDAP_ATTRIBUTE_USER_UNIQUE_IDENTIFIER = "uuid";
        LDAP_ATTRIBUTE_USER_USERNAME = "uid";
        LDAP_ATTRIBUTE_USER_EMAIL = "mail";
        LDAP_ATTRIBUTE_USER_FIRST_NAME = "firstname";
        LDAP_ATTRIBUTE_USER_LAST_NAME = "lastname";

        LDAP_ATTRIBUTE_GROUP_UNIQUE_IDENTIFIER = "uuid";
        LDAP_ATTRIBUTE_GROUP_NAME = "displayname";

        # Admin Group
        LDAP_ADMIN_GROUP_NAME = "pocket-id_admin";
      }
    ];
  };
}
