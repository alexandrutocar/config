{
  config,
  sigil,
  pkgs,
  ...
}: let
  serverDomain = "ueuie.earth";
  serverOrigin = "https://${serverDomain}";
in let
  notesPackage = pkgs.notes serverOrigin;
in {
  services.caddy = {
    inherit (notesPackage.caddy) extraConfig;

    virtualHosts = {
      ${serverOrigin} = {
        listenAddresses = [
          "${sigil.self.addresses.gua}"
        ];

        logFormat = ''
          output file ${config.services.caddy.logDir}/${serverDomain}.access.log
          format json
        '';

        extraConfig = ''
          tls {
            issuer acme {
              email hostmaster@${serverDomain}
              disable_http_challenge
            }
          }

          import ${notesPackage.caddy.importBlock}

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
