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
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64; echo -n | systemd-creds encrypt --with-key=host --name=jwt_secret - -
            "jwt_secret" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADWJc8u+fhzg1yZVCgAAAAAKlXQELPUP+EcpDM
              Xxqu8Z9BVzSOWCukhE4ctBNsM9HPtDwqiTcd9pZ/UYmDbZ8dYTNPosEtr09nMJlHZKT1gqqq+N+eBoX
              kIlHeFqsh9/5m5xr7N8CxFU1kHMNsUe72XzoJODfttIn9M/QxtSaMOEg==
            '';
            # echo -n '<password>' 
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

        jwt_secret_file = "/run/credentials/lldap.service/jwt_secret";

        ldap_host = sigil.self.addresses.ula;
        ldap_port = 3890;
        ldap_base_dn = "dc=intra,dc=net,dc=internal";
        ldap_user_dn = "Alex";
        ldap_user_email = "alex@intra.net.internal";
        ldap_user_pass_file = "/run/credentials/lldap.service/ldap_user_pass";
      };
    };
  };
}
