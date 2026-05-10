{
  container,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
in {
  services.nginx.virtualHosts = let
    inherit (container.self) localAddress;
  in
    mkMerge [
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Reject requests not matched against any of the explicitly
      #       specified server names.
      # ────────────────────────────────────────────────────────────────────────
      {
        _ = {
          default = true;

          extraConfig = ''
            access_log /var/log/nginx/default.access.log analytics;
            error_log /var/log/nginx/default.error.log;
            ssl_reject_handshake on;
            return 444;
          '';

          listen = [
            {
              addr = localAddress;
              port = 80;
            }
            {
              addr = localAddress;
              port = 443;
              ssl = true;
            }
          ];
        };
      }
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Append 'www' for requests to 'ueuie.dev'.
      # ────────────────────────────────────────────────────────────────────────
      {
        "ueuie.dev" = {
          extraConfig = ''
            access_log /var/log/nginx/ueuie.dev.access.log analytics;
            error_log /var/log/nginx/ueuie.dev.error.log;

            return 301 $scheme://www.ueuie.dev$request_uri;
          '';

          forceSSL = true;

          listen = [
            {
              addr = localAddress;
              port = 80;
            }
            {
              addr = localAddress;
              port = 443;
              ssl = true;
            }
          ];

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
      }
      {
        "www.ueuie.dev" = {
          extraConfig = ''
            access_log /var/log/nginx/www.ueuie.dev.access.log analytics;
            error_log /var/log/nginx/www.ueuie.dev.error.log;

            error_page    404    /404.html;
          '';

          forceSSL = true;

          kTLS = true;

          listen = [
            {
              addr = localAddress;
              port = 80;
            }
            {
              addr = localAddress;
              port = 443;
              ssl = true;
            }
          ];

          locations = {
            "/" = {
              root = "${./assets/www.ueuie.dev}";
            };
          };

          serverName = "www.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
        "blog.ueuie.dev" = {
          extraConfig = ''
            access_log /var/log/nginx/blog.ueuie.dev.access.log analytics;
            error_log /var/log/nginx/blog.ueuie.dev.error.log;

            error_page    404    /404.html;
          '';

          forceSSL = true;

          kTLS = true;

          listen = [
            {
              addr = localAddress;
              port = 80;
            }
            {
              addr = localAddress;
              port = 443;
              ssl = true;
            }
          ];

          locations = {
            "/" = {
              root = "${./assets/blog.ueuie.dev}";
            };
          };

          serverName = "blog.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
      }
    ];
}
