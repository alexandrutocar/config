{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
in let
  extraConfig = ''
    access_log /var/log/nginx/ollama.ai.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/ollama.ai.intra.net.internal.error.log;
    client_max_body_size 0;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "ollama.ai.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/ollama.ai.intra.net.internal.pem";

  sslCertificateKey = "${credentialsDirectory "nginx"}/ollama.ai.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/ollama.ai.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=ollama.ai.intra.net.internal-key.pem - -
      "ollama.ai.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADSKgKtNQnXdCTp5JkAAAAAYUNA6sgCLOr12yV
        Q5aPBeCb5oi9a0CJUE0m5eJS+qHDi8Mh73xEC9qbA0M3ei1a2tq9QERreOiTJ6YA179QryGrWa+eL4c
        /O1nwp1yKTjVX5znlzo2TV+QaYyQb14HVyOmAVisl3x/ptWpVOUcUuBZO3EG/EADtnRE0YNE/rTtAsi
        0NpDc2ctH6JiKWFXF09bHXrPtGy3H3EQRcPx1ToF04+penwygdqs1MWkFmd/wHnFuXYLEZ0KMuU25rz
        /qGRZQ38ZmxpVPThSWIwKSPVN7m4uzlghSODIOkdhJHyFUzvc6B6wURaOFYiHcypJmKueI62GKH4nhr
        ksdApEOWUG0ZvUQjbIYwB50go9buIH4CjRX+HqshEluIolyNWV9Gyw2FdlR4THFPZ+bE=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "ollama.ai.intra.net.internal" = {
      inherit extraConfig kTLS onlySSL serverName sslCertificate sslCertificateKey;

      listen = [
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 11434;
          ssl = true;
        }
      ];

      locations = {
        "/" = {
          extraConfig = ''
            # ────────────────────────────────────────────────────────────────────────
            # NOTE: Tokens must reach the client immediately.
            # ────────────────────────────────────────────────────────────────────────
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_cache off;
            gzip off;

            # ────────────────────────────────────────────────────────────────────────
            # NOTE: Cold start exceeds defaults.
            # ────────────────────────────────────────────────────────────────────────
            proxy_connect_timeout 60s;
            proxy_send_timeout 3600s;
            proxy_read_timeout 3600s;
            send_timeout 3600s;

            # ────────────────────────────────────────────────────────────────────────
            # NOTE: Do not replay a non-idempotent generation on another attempt.
            # ────────────────────────────────────────────────────────────────────────
            proxy_next_upstream off;
          '';

          proxyPass = "http://${ipv6.enclose sigil.containers.intra."d86c8e1c-2bcd-4d2f-a3b2-7962afc28a51".addresses.ula}:11434";
        };
      };
    };
  };
}
