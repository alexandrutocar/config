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
  inherit (config.services) forgejo;
in let
  colleiContainers = shortPathToContainers self.nixosConfigurations.collei.config;
in {
  systemd = {
    services = {
      forgejo = {
        serviceConfig = {
          IPAddressAllow = [
            (with forgejo.settings.server; HTTP_ADDR)
          ];
        };
      };
    };
  };

  services = {
    forgejo = {
      settings = {
        server = let
          HTTP_ADDR = sigil.self |> getULA |> ip.toCompressed;
          HTTP_PORT = 8080;

          DOMAIN = "forge.ueuie.earth";
        in {
          inherit DOMAIN HTTP_ADDR HTTP_PORT;

          ROOT_URL = url.mkOrigin "https" DOMAIN null;

          LOCAL_ROOT_URL = url.interface.toOrigin "http" (url.mkInterface HTTP_ADDR HTTP_PORT) |> url.origin.toString;
        };

        security = {
          REVERSE_PROXY_LIMIT = 1;
          REVERSE_PROXY_TRUSTED_PROXIES = colleiContainers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab |> getULA |> ip.toCIDR;
        };
      };
    };
  };
}
