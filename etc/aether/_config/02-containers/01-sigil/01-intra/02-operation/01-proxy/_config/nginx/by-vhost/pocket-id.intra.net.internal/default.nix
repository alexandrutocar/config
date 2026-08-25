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
    access_log /var/log/nginx/pocket-id.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/pocket-id.intra.net.internal.error.log;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "pocket-id.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/pocket-id.intra.net.internal.pem";

  sslCertificateKey = "/run/credentials/nginx.service/pocket-id.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/pocket-id.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=pocket-id.intra.net.internal-key.pem - -
      "pocket-id.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACAVFb8GH+Y0f+AyTEAAAAAr+DxzbiYOIIRcZV
        GMFwzw7zyNM2jawRDRAGMEqX+LocnbpXjjM/PfbrZvHPBcBpxwrC7jbTDYCTpiwv1/Himsh9r+7MnoI
        mhkd9mUzSg8sAen7eaWkTG5rKBomUB8WjG7n6WFwWEgUSF0PSWwJ2xj62XY2vjJlxww01pM4aI+uI8V
        gPy1H40NwKt6TZ6UUr7HUPVLxRdwvgoh1+ZDHOgDeJIlyDSJ3FIK83xr2DH7kwEhamGdK3u2tvVyUIN
        i0RUyIGeNL2Zc6K9jmeZpHBi+oFskYCszUSf06hlqNwx3v+iXE+CpOe7JPJ1FwL157mCIbbLvMrlwDp
        rDJSKTsW9ZwNgaICwii0CIE06BLnH19Vz8KDfiP2ekNxcjac1xkC1Auc2SN/RDRZyMbc=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "pocket-id.intra.net.internal" = {
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
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."c38a828e-58a7-49af-894d-ba02f936d211".addresses.ula}:8081";
        };
      };
    };
  };
}
