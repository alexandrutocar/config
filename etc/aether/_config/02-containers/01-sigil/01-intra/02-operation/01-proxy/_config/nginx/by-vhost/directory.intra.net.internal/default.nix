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
      "directory.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADpCdf4iwLsyilfNrsAAAAAEXnleXIKOfM8+YD
        zfM2bfwDMO2Lq2sCJAybXCehAL5wLmfjLkJ+YpyJAaF4IWKcAVRTIzyrDtThxMxxn1fAxwilyzCf5JN
        6Va0vpjWxGYQYrvO5N+miD2kkojSp5AXLKi07GVLgC6CjOtnvBHxRa23j/sxnNaj4Hq07XPPbrifpoC
        0Y/Iu1s7TGgCauJwjc6NeYQm0SU941qCVCx31C7D/sKvtlMHxT+P/rTagZaF2RSYveqre+qcqW13DOt
        uLsoqSJ3Y+FezUX5OBGbJroe1+ASWwLwRx7EI6F74Ux3AKuX08Gzk4gVczFpiylSYT5aissHh8WrHL4
        taKiiBl86mYxeqB7oYlfpdxkNQtPyhFQvwTNzBcpKEd6+oaDGR+2PaG6dj8/4tU0mm2A=
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
