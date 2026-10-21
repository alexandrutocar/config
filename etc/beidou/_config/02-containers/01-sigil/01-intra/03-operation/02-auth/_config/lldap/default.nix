{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.lldap.settings.ldap_port # LDAP
        config.services.lldap.settings.http_port # HTTP
      ];
    };
  };

  systemd = {
    services = {
      lldap = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=key_seed - -
            "key_seed" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACQinkGoi8BKbL8Pa0AAAAAxi1pl9JCiZ0Urq9
              KoGEL7/7I/3qL+727NTUt/HHWXoEkEQvXD/CZgPmBO0L59hBk3W0ftTXZeXCFi+QzkDGUtLXk3it0YB
              dr+cK8/fcbDsgt8+xCY4jfXfXtcMQyxvsO1/XpkE1Ap7CQmUX8COVTqw==
            '';
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=jwt_secret - -
            "jwt_secret" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADWJc8u+fhzg1yZVCgAAAAAKlXQELPUP+EcpDM
              Xxqu8Z9BVzSOWCukhE4ctBNsM9HPtDwqiTcd9pZ/UYmDbZ8dYTNPosEtr09nMJlHZKT1gqqq+N+eBoX
              kIlHeFqsh9/5m5xr7N8CxFU1kHMNsUe72XzoJODfttIn9M/QxtSaMOEg==
            '';
            # echo -n '<password>' | systemd-creds encrypt --with-key=host --name=ldap_user_pass - -
            "ldap_user_pass" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAXdL1lDO55zci9qsgAAAAAcLZYvCOR55WtJJX
              CwuFuetjuDJYEF6ZDTAND87+KARUIx2QdBl/8BAFekL3y9jRKxXAyYPSDRKdZ2Ajs0MOCN4wqpmRhau
              yaquOZbbm/lFxx5H7odhhGhA==
            '';
          };
        };
      };
    };
  };

  services = {
    lldap = {
      enable = true;
      settings = {
        force_ldap_user_pass_reset = "always";
        http_host = sigil.self.addresses.ula;
        http_port = 8080;
        http_url = "https://directory.intra.net.internal";

        key_seed_file = "/run/credentials/lldap.service/key_seed";

        jwt_secret_file = "/run/credentials/lldap.service/jwt_secret";

        ldap_host = "::";
        ldap_port = 3890;
        ldap_base_dn = "dc=intra,dc=net,dc=internal";
        ldap_user_dn = "Alex";
        ldap_user_email = "alex@intra.net.internal";
        ldap_user_pass_file = "/run/credentials/lldap.service/ldap_user_pass";
      };
    };
  };
}
