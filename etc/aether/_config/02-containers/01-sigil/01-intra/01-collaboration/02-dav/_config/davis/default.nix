{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        8080 # HTTP
      ];
    };
  };

  systemd = {
    services = let
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          admin-password = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADs+H0i2u/hSoAR3W4AAAAAoSGd5oSLdo5YBCZ
            Vf2/L+QQH3oZLNdDumHGbutFJuTgQZ2iBfwU083BHr5/wVwAdRTV46MSK3/ymeHCdTUArwS/sMb8KZK
            uhu9sxlgZlteQIDyf7S51U7g8=
          '';
          app-secret = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAG71HJWWlfUTLpJuoAAAAA1hMeJ362c2k7XAi
            AbIuRViljRmdu5y0yO0TdkrcjRulwJRqs/yDGimWNeWkUs0th8/iZ8iKnnnshnqPGEG6q9I9zrBUskc
            m4SJrPdkXXlkoqUEEPVRx9NkqBtAzM1Pegs3cRWrmRSeWIYoo6WhauFw==
          '';
        };
      };
    in {
      davis-database-migrations = {
        inherit serviceConfig;
      };
      phpfpm-davis = {
        inherit serviceConfig;
      };
    };
  };

  services = {
    davis = {
      enable = true;

      settings = {
        # General
        # -------
        APP_ENV = "prod";
        APP_SECRET.cred = "app-secret";

        # Auth
        # ----
        AUTH_METHOD = "LDAP";
        LDAP_AUTH_URL = "ldap://${ipv6.enclose sigil.containers.intra."c38a828e-58a7-49af-894d-ba02f936d211".addresses.ula}:3890";
        LDAP_DN_PATTERN = "uid=%u,ou=people,dc=intra,dc=net,dc=internal";
        LDAP_MAIL_ATTRIBUTE = "mail";
        LDAP_AUTH_USER_AUTOCREATE = "true";
        LDAP_CERTIFICATE_CHECKING_STRATEGY = "try";

        # Storage
        # -------
        DATABASE_DRIVER = "sqlite";
        DATABASE_URL = builtins.concatStringsSep "/" ["sqlite://" config.services.davis.dataDir "data.db"];

        # Calendar
        # --------
        CALDAV_ENABLED = "true";
        INVITE_FROM_ADDRESS = "no-reply@intra.net.internal";
        PUBLIC_CALENDARS_ENABLED = "true";

        # Contacts
        # --------
        CARDDAV_ENABLED = "true";
        BIRTHDAY_REMINDER_OFFSET = "PT9H";

        # DAV
        # ---
        WEBDAV_ENABLED = "true";

        WEBDAV_TMP_DIR = "/tmp";

        WEBDAV_HOMES_DIR = "/var/lib/davis/homes";
        WEBDAV_PUBLIC_DIR = "/var/lib/davis/public";

        # Administration
        # --------------
        ADMIN_LOGIN = "184a8e53a64f692bf42f99b9fe0aad0a";
        ADMIN_PASSWORD.cred = "admin-password";
      };

      nginx = {
        listen = [
          {
            addr = ipv6.enclose "::";
            port = 8080;
          }
        ];
      };
    };
  };
}
