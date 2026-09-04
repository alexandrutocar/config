{
  config,
  sigil,
  pkgs,
  ...
}: let
  serverName = "ueuie.earth";
in {
  services.caddy = {
    inherit (pkgs.notes.caddy) extraConfig;

    virtualHosts = {
      "https://${serverName}" = {
        listenAddresses = [
          "${sigil.self.addresses.gua}"
        ];

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

          import ${pkgs.notes.caddy.importBlock}

          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            X-Content-Type-Options "nosniff"
            X-Frame-Options "DENY"
          }
        '';
      };
    };
  };
}
