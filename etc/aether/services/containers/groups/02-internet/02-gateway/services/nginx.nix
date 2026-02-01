# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy, prometheus exporter...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self intranet-monitoring internet-harmonia internet-uptime internet-alkaline internet-invidious;
in {
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    statusPage = true;

    virtualHosts = {
      _ = {
        default = true;
        extraConfig = ''
          return 444;
        '';
      };

      "ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        extraConfig = ''
          return 301 $scheme://www.ueuie.dev$request_uri;
        '';
      };

      "www.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;
        locations = {
          "/" = {
            root = ./ueuie;
          };
        };

        extraConfig = ''
          error_page    404    /404.html;
        '';
      };

      "cache.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/cache.ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/cache.ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/cache.ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${internet-harmonia.localAddress}:8080";
          };
        };
      };

      "status.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${internet-uptime.localAddress}:8080";
            proxyWebsockets = true;
          };
        };
      };

      "metrics.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-monitoring.localAddress}:8080";
            proxyWebsockets = true;
          };
        };
      };

      "invidious.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${internet-invidious.localAddress}:8080";
          };
        };
      };

      "t.ueuie.dev" = {
        sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
        sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${internet-alkaline.localAddress}:8080";
            proxyWebsockets = true;
          };
        };
      };
    };
  };

  services.prometheus.exporters.nginx = {
    enable = true;
    port = 9090;
    listenAddress = self.localAddress;
  };
}
