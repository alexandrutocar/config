# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx, reverse proxy, prometheus exporter...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self x0-fin x0-flx x0-git x0-pim x0-ins;
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

      "repos.aether.ip" = {
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
            proxyPass = "http://${x0-git.address}:8080";
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
            proxyPass = "http://${x0-flx.address}:8080";
          };
        };
      };

      "metrics.aether.ip" = {
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
            proxyPass = "http://${x0-ins.address}:8080";
            proxyWebsockets = true;
            recommendedProxySettings = true;
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
            proxyPass = "http://${x0-fin.address}:8080";
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
            proxyPass = "http://${x0-ins.address}:9090";
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
