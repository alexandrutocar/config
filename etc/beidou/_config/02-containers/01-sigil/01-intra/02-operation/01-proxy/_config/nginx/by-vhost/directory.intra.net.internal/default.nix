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
    access_log /var/log/nginx/directory.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/directory.intra.net.internal.error.log;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "directory.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/directory.intra.net.internal.pem";

  sslCertificateKey = "/run/credentials/nginx.service/directory.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/directory.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=directory.intra.net.internal-key.pem - -
      "directory.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADWeSCv9M0sfs/sCGEAAAAAjBVReEixdmnpJ4+
        YrjUrYdRC3nRQY5Cq/1LpnEftw3x0iL47GJb+o4s+VGdF/e6OpB17sQ1nZNHquowK/0QBDXJUURtZiL
        3M/51g+fGkxvtiLNR9xGKUarfdUX3pXhdwpp2G1OnoMtFf2x81mr5ToaNH2UOA4abNvwzfp7KbrT48/
        37WiYN8ct3YyTAYjU6MbpBOSaMFzYw2lJTDL43NzuS+tkn8fJuDHsLCPcdqXOmE0ij8WHzfjxV0CDwJ
        mjbGbfC0+qm4KqN4Yoj2+5Yua2sVXvGPErBBr0Kf78m/uF4nplFa1nZyOU1YaBDR22qF2K+vAeB2cUl
        5mI96QFtoWP0rhPZe+JJwsuton6np+s6qpwa4nrplgE8obg2OVC8VI6bmlWTAbFdIp0Q=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "directory.intra.net.internal" = {
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
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."c38a828e-58a7-49af-894d-ba02f936d211".addresses.ula}:8080";
        };
      };
    };
  };
}
