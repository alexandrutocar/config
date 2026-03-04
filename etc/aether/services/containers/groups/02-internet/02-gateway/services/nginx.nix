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

  inherit (container) self internet-harmonia internet-uptime;

  ngx_http_geoip2_module = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ngx_http_geoip2_module";
    version = "3.4";

    src = pkgs.fetchFromGitHub {
      owner = "leev";
      repo = finalAttrs.pname;
      tag = finalAttrs.version;
      hash = "sha256-CAs1JZsHY7RymSBYbumC2BENsXtZP3p4ljH5QKwz5yg=";
    };

    installPhase = ''
      mkdir $out
      cp *.c config $out/
    '';
  });
in {
  services.nginx = {
    enable = true;

    package =
      (pkgs.nginx.overrideAttrs (oldAttrs: rec {
        configureFlags = oldAttrs.configureFlags ++ ["--add-module=${ngx_http_geoip2_module}"];
        buildInputs = oldAttrs.buildInputs ++ [pkgs.libmaxminddb];
      })).override {
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
        "status.ueuie.dev/uptime" = {
          extraConfig = ''
            access_log /var/log/nginx/status.ueuie.dev.access.log analytics;
            error_log /var/log/nginx/status.ueuie.dev.error.log;
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
              proxyPass = "http://${internet-uptime.localAddress}:8080";
              proxyWebsockets = true;
            };
          };

          serverName = "status.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
        "cache.ueuie.dev/harmonia" = {
          extraConfig = ''
            access_log  /var/log/nginx/cache.ueuie.dev.access.log analytics;
            error_log              /var/log/nginx/cache.ueuie.dev.error.log;
            proxy_buffering                                             off;
            proxy_request_buffering                                     off;
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
              proxyPass = "http://${internet-harmonia.localAddress}:8080";
            };
          };

          serverName = "cache.ueuie.dev";

          sslCertificate = "/var/lib/acme/ueuie.dev/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/ueuie.dev/key.pem";
          sslTrustedCertificate = "/var/lib/acme/ueuie.dev/chain.pem";
        };
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
