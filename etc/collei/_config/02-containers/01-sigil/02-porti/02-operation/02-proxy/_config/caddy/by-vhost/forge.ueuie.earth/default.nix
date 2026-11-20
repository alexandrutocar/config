{
  config,
  sigil,
  self,
  lib,
  ...
}: let
  inherit (lib.extra) ip url;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
in let
  fischlContainers = shortPathToContainers self.nixosConfigurations.fischl.config;
in let
  serverDomain = "forge.ueuie.earth";
  serverOrigin = url.mkOrigin "https" serverDomain null;
in {
  services = {
    caddy = {
      virtualHosts = {
        ${serverOrigin} = {
          listenAddresses = [
            (sigil.self.addresses.ipv6.extra.gua.forge |> ip.toCompressed)
            (sigil.self |> getULA |> ip.toCompressed)
          ];

          logFormat = ''
            output file ${config.services.caddy.logDir}/${serverDomain}.access.log
            format json
          '';

          extraConfig = let
            upstream = let
              target = fischlContainers.porti.ea3680ca-4e51-4e86-b467-7f85d573834e;
            in
              url.mkInterface (target |> getULA) 8080;
          in ''
            tls {
              issuer acme {
                email acme@ueuie.earth
                disable_http_challenge
              }
            }

            encode zstd gzip

            header {
              Strict-Transport-Security "max-age=31536000; includeSubDomains"
              X-Content-Type-Options "nosniff"
              Referrer-Policy "strict-origin-when-cross-origin"
              Permissions-Policy "interest-cohort=(), browsing-topics=()"
              -Server
            }

            @metrics {
              path /metrics
              not remote_ip private_ranges
            }
            respond @metrics 404

            request_body {
              max_size 16GiB
            }

            reverse_proxy ${upstream}
          '';
        };
      };
    };
  };
}
