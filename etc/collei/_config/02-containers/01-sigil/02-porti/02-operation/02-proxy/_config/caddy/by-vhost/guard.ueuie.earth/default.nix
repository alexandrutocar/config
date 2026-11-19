{
  config,
  sigil,
  self,
  lib,
  ...
}: let
  inherit (lib.extra) ip url;
  inherit (lib.extra.sigil) getGUA getULA shortPathToContainers;
in let
  fischlContainers = shortPathToContainers self.nixosConfigurations.fischl.config;
in let
  serverDomain = "guard.ueuie.earth";
  serverOrigin = url.mkURL {
    scheme = "https";
    host = serverDomain;
  };
in {
  services.caddy = {
    virtualHosts = {
      ${serverOrigin} = {
        listenAddresses = [
          (sigil.self |> getGUA |> ip.toCompressed)
        ];

        logFormat = ''
          output file ${config.services.caddy.logDir}/${serverDomain}.access.log
          format json
        '';

        extraConfig = let
          target = fischlContainers.porti.c4a54e9b-fab6-4f57-ad12-3cfc34c950ab;
        in ''
          tls {
            issuer acme {
              email acme@ueuie.earth
              disable_http_challenge
            }
          }

          reverse_proxy ${url.mkInterface (target |> getULA) 8080}
        '';
      };
    };
  };
}
