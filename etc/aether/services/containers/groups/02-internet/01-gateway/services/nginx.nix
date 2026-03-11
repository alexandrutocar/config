# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy, prometheus exporter...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;

  inherit (container) self;
in {
  services.nginx = {
    enable = true;

    package = pkgs.nginx.override {
      withGeoIP = true;
    };

    recommendedBrotliSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    statusPage = true;

    virtualHosts = mkMerge [
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
              addr = self.localAddress;
              port = 80;
            }
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];
        };
      }
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
              addr = self.localAddress;
              port = 80;
            }
            {
              addr = self.localAddress;
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
        "blog.ueuie.dev/static" = {
          extraConfig = ''
            access_log /var/log/nginx/blog.ueuie.dev.access.log analytics;
            error_log /var/log/nginx/blog.ueuie.dev.error.log;

            error_page    404    /404.html;
          '';

          forceSSL = true;

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 80;
            }
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          locations = {
            "/" = {
              root = "${../etcetera/static/blog}";
            };
          };

          serverName = "blog.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
        "www.ueuie.dev/static" = {
          extraConfig = ''
            access_log /var/log/nginx/www.ueuie.dev.access.log analytics;
            error_log /var/log/nginx/www.ueuie.dev.error.log;

            error_page    404    /404.html;
          '';

          forceSSL = true;

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 80;
            }
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          locations = {
            "/" = {
              root = "${../etcetera/static/land}";
            };
          };

          serverName = "www.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
      }
    ];
  };

  services.prometheus.exporters.nginx = {
    enable = true;
    port = 9090;
    listenAddress = self.localAddress;
  };
}
