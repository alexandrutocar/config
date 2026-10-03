{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
in let
  extraConfig = ''
    access_log /var/log/nginx/music.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/music.intra.net.internal.error.log;
  '';

  kTLS = true;

  # onlySSL = true;

  serverName = "music.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/music.intra.net.internal.pem";

  sslCertificateKey = "/run/credentials/nginx.service/music.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/music.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=music.intra.net.internal-key.pem - -
      "music.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADPAqtGIYQO6vfyn0UAAAAAylYsWgvAIIU2rdm
        piJ3Mxx9Hee9afwWMIf7++AcVlPSpAGKu9eBbUE6WL1l68MyQzApqSauAN4wubNBE+O0NvlZPNdzuu8
        clMmlAlWp/UpiABkMRSBl7Iu9HrBrPh8HlVjdicubo3PkI94jVtjyXzvODUr9m0IYDg9CT7iBCh82V6
        aNzXrPs2SnPJPmjr2yZgouf+irOYgEHNthQrLbLPtYYtb7Jd3cEeq2dE7ZtYWuPvZz8feYLUpKcwD9c
        ELQQ2cQmSLVMgfIhvLjbmK3RhQt2EzgYcTmwrGhlG2FzO1iIHNWYAoAZHvU5vZKGK1XJHrhCXg+uUPf
        jntK1gRN4GUIw5tTo1u54RwvbFoD9v/hXt2AKJDgWUMatdR1e/QwXwqHqg4XSc7sCg1Y=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "music.intra.net.internal" = {
      inherit extraConfig kTLS serverName sslCertificate sslCertificateKey;

      listen = [
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 443;
          ssl = true;
        }
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 80;
        }
      ];

      locations = {
        "/" = {
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."fecc0d40-eb4e-43d4-b0ef-c0627fcce582".addresses.ula}:8080";
        };
      };
    };
  };
}
