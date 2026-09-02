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

        # Hashed Assets
        header /_astro/* Cache-Control "public, max-age=31536000, immutable"

        # HTML Pages
        header ?Cache-Control "no-cache"

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
