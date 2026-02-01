# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy, prometheus exporter...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self intranet-ml intranet-accounting intranet-feed intranet-dav intranet-monitoring;
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

      "aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";

        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

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
      };

      "ml.aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-ml.localAddress}:8080";
          };
        };
      };

      "finances.aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-accounting.localAddress}:8080";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
      };

      "feed.aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";

        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-feed.localAddress}:8080";
          };
        };
      };

      "monitoring.aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-monitoring.localAddress}:8080";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
      };

      "exporters.aether.ip" = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # sslTrustedCertificate = "/var/lib/acme/aether.ip/chain.pem";
        sslCertificateKey = "/var/lib/acme/aether.ip/key.pem";
        sslCertificate = "/var/lib/acme/aether.ip/fullchain.pem";

        forceSSL = true;
        kTLS = true;

        locations = {
          "/" = {
            proxyPass = "http://${intranet-monitoring.localAddress}:9090";
            proxyWebsockets = true;
            recommendedProxySettings = true;
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
