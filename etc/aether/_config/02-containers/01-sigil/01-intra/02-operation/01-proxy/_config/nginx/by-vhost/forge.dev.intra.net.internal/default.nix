{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
  inherit (lib.extra.net) ipv6;
in let
  extraConfig = ''
    access_log /var/log/nginx/forge.dev.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/forge.dev.intra.net.internal.error.log;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "forge.dev.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/forge.dev.intra.net.internal.pem";

  sslCertificateKey = "/run/credentials/nginx.service/forge.dev.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/forge.dev.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=forge.dev.intra.net.internal-key.pem - -
      "forge.dev.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAB6Eo+qVQ8KNXDkymoAAAAAei6Npl8gqbYw1zh
        inWdav4xBTkRJiEvUAjKey/bOMrivc1suoiKq1zICKLjnMFrJBqzhtFNpCMkNUnGig+yypHNYmufqgg
        4bWR7FqwXG3dYZf8D7hLULvj4qcesRK0pmFgL7ZRZ+BSoXpHlWXQUyast7luY7y2pkEyg+QE9wLj5on
        8whT99hPVKSFdhiI7Sn/+FlV7hQbKiUfxeQV2CW8sO23rDNxRX/nyAnH5NI/+a7Lg7NIixOuU7kFrb+
        iAD/B1xMj9l7N+aOIwv3N8Qk3uFR3SmIRMmyks7gWWv/Pk1UAW+pWd8Fl6v13G4jvKI0gVj5hxAwfJi
        9+7JEVY40M+K+El1m0DJ2wKnBxIuCgPL7IQ/gwvsEsjP0IA9Pc1YaG6TBMm5SB4Z63jM=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "forge.dev.intra.net.internal" = {
      inherit extraConfig kTLS onlySSL serverName sslCertificate sslCertificateKey;

      listen = [
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 443;
          ssl = true;
        }
      ];

      locations = {
        "/" = {
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."acda4bf3-2678-43c5-bae9-e67bd8cb710d".addresses.ula}:8080";
        };
      };
    };
  };
}
