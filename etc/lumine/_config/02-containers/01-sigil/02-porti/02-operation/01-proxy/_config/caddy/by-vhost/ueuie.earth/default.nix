{
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
        output file /var/log/caddy/${serverName}.access.log
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
        encode zstd gzip

        @assets path /_astro/*
        header @assets Cache-Control "public, max-age=31536000, immutable"

        @nonassets not path /_astro/*
        header @nonassets ?Cache-Control "no-cache"

        @static file {
          try_files {path} {path}/index.html {path}.html
        }

        handle @static {
          rewrite * {file_match.relative}
          file_server
        }
        
        handle_errors {
          @404 {
              expression {http.error.status_code} == 404
          }
          rewrite @404 /404.html
          file_server
        }
      '';
    };
  };
}
