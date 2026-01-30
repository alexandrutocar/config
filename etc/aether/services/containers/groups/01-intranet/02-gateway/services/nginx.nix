# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy, prometheus exporter...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self intranet-accounting intranet-feed x0-pim intranet-monitoring;
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
            proxyPass = "http://${x0-pim.address}:8080";
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

      "accounting.aether.ip" = {
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
            proxyPass = "http://${intranet-accounting.address}:8080";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
      };

      "reader.aether.ip" = {
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
            proxyPass = "http://${intranet-feed.address}:8080";
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
            proxyPass = "http://${intranet-monitoring.address}:8080";
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
            proxyPass = "http://${intranet-monitoring.address}:9090";
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
    listenAddress = self.address;
  };
}
