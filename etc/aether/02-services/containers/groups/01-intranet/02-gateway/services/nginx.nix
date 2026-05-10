# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
  inherit (container) self intranet-harmonia intranet-ml intranet-dav intranet-sync intranet-monitoring;
in {
  services.nginx = {
    enable = true;

    recommendedBrotliSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    statusPage = true;

    virtualHosts = mkMerge [
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
        "aether.ip/ml" = {
          extraConfig = ''
            access_log /var/log/nginx/aether.ip.access.log analytics;
            error_log /var/log/nginx/aether.ip.error.log;
          '';

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 11434;
              ssl = true;
            }
          ];

          onlySSL = true;

          locations = {
            "/" = {
              proxyPass = "http://${intranet-ml.localAddress}:8080";
            };
          };

          serverName = "aether.ip";

          sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";

          # ────────────────────────────────────────────────────────────────────────
          # TODO: Compile the right chain.pem.
          # ────────────────────────────────────────────────────────────────────────
          # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        };
        "aether.ip/dav" = {
          extraConfig = ''
            access_log /var/log/nginx/aether.ip.access.log analytics;
            error_log /var/log/nginx/aether.ip.error.log;
          '';

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          onlySSL = true;

          locations = {
            "/" = {
              proxyPass = "http://${intranet-dav.localAddress}:8080";
            };

            "/.well-known/" = {
              alias = "/usr/share/html/.well-known/";
              tryFiles = "$uri =404";
              extraConfig = ''
                default_type application/x-apple-aspen-config;
              '';
            };
          };

          serverName = "aether.ip";

          sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";

          # ────────────────────────────────────────────────────────────────────────
          # TODO: Compile the right chain.pem.
          # ────────────────────────────────────────────────────────────────────────
          # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        };
      }
      {
        "monitoring.aether.ip/monitoring" = {
          extraConfig = ''
            access_log /var/log/nginx/monitoring.aether.ip.access.log analytics;
            error_log /var/log/nginx/monitoring.aether.ip.error.log;
          '';

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          onlySSL = true;

          locations = {
            "/" = {
              proxyPass = "http://${intranet-monitoring.localAddress}:8080";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };

          serverName = "monitoring.aether.ip";

          sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";

          # ────────────────────────────────────────────────────────────────────────
          # TODO: Compile the right chain.pem.
          # ────────────────────────────────────────────────────────────────────────
          # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        };

        "cache.aether.ip/harmonia" = {
          extraConfig = ''
            access_log  /var/log/nginx/cache.aether.ip.access.log analytics;
            error_log              /var/log/nginx/cache.aether.ip.error.log;
            proxy_buffering                                             off;
            proxy_request_buffering                                     off;
          '';

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          onlySSL = true;

          locations = {
            "/" = {
              proxyPass = "http://${intranet-harmonia.localAddress}:8080";
            };
          };

          serverName = "cache.aether.ip";

          sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";

          # ────────────────────────────────────────────────────────────────────────
          # TODO: Compile the right chain.pem.
          # ────────────────────────────────────────────────────────────────────────
          # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        };

        "sync.aether.ip/anki" = {
          extraConfig = ''
            access_log /var/log/nginx/sync.aether.ip.access.log analytics;
            error_log /var/log/nginx/sync.aether.ip.error.log;
          '';

          kTLS = true;

          listen = [
            {
              addr = self.localAddress;
              port = 443;
              ssl = true;
            }
          ];

          onlySSL = true;

          locations = {
            "/" = {
              proxyPass = "http://${intranet-sync.localAddress}:8080";
            };
          };

          serverName = "sync.aether.ip";

          sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";

          # ────────────────────────────────────────────────────────────────────────
          # TODO: Compile the right chain.pem.
          # ────────────────────────────────────────────────────────────────────────
          # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        };
      }
    ];
  };
}
