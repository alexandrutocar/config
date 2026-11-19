{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses radii;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = let
        systemSite = addresses.provider.hetzner-cloud-server;
      in {
        inherit (radii.site.${hostName}) hostAddress;

        gua = {
          prefix = systemSite.hosts.${hostName}.managedNetworks.ipv6.gua;
        };

        ula = {
          inherit (radii.site.${hostName}) prefix;
        };
      };
    };
  };
}
