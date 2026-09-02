{
  config,
  sigil,
  pkgs,
  ...
}: let
  serverName = "ueuie.earth";
in {
  services.caddy.virtualHosts = {
    "ueuie.earth" = {
      listenAddresses = ["${sigil.self.addresses.gua}"];

      logFormat = ''
        output file ${config.services.caddy.logDir}/${serverName}.access.log
        format json
      '';

      extraConfig = ''
        tls {
          issuer acme {
            email hostmaster@${serverName}
            disable_http_challenge
          }
        }

        root * ${pkgs.notes}

        # Security Headers
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
        }

        # Hashed Assets
        header /_astro/* Cache-Control "public, max-age=31536000, immutable"

        # HTML Pages
        header ?Cache-Control "no-cache"

        # Icons
        @icons path /favicon.svg /img/icons/*
        header @icons Cache-Control "max-age=3600, must-revalidate"

        # Compression
        encode zstd gzip
        file_server { precompressed br gzip zstd }

        # Error Handling
        handle_errors {
          @404 { expression {http.error.status_code} == 404 }
          rewrite @404 /404.html
          file_server { precompressed br gzip zstd }
        }
      '';
    };
  };
}
