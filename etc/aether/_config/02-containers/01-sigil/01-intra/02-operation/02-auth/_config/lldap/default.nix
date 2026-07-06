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
            "jwt_secret" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAjO51Vp+98W3pYP4EAAAAANx1VJY243YPIc/F
              OSceU1W6VTD23JLN4Uh1y6YeYOX1RbIF13MzG48XKhfgpQQ8WJ9vaxJfEQYWafJ6jIjof1ZZhrfIeH+
              7pkoMDw+SVFN17EnB0arL+DkZvD8WglQfoAXfsjtazIYKNS/3t3PjPKQ==
            '';
            "ldap_user_pass" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAJfY8KplLBTeJfzbEAAAAAVhbA8L5WymLW0W6
              2PRmis1I449XxPBnEJfqwIE9kWVFVd7cVCfmWoGbt1S2rfCvqdt/EhU7LO1ZDLMZiQBaNN7WGLjQSEB
              RK0c0SEapAcSr/EzRkZKobwg==
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
