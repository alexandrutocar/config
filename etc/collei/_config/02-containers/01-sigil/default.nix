{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses networks;
  inherit (lib.extra.ip) toCompressed;
  inherit (lib.extra.ip.network) toPrefixGroups;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = let
        systemSite = addresses.provider.hetzner-cloud-server;
      in {
        gua = {
          prefix = systemSite.hosts.${hostName}.managedNetworks.ipv6.gua |> toPrefixGroups;
        };

        ula = {
          prefix = networks.aether.internal.net._meta.network |> toPrefixGroups;
          source = networks.aether.internal.net.hosts.collei |> toCompressed;
        };
      };
    };
  };
}
