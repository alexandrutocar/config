{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses networks;
  inherit (lib.extra) ip;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = let
        systemSite = addresses.provider.hetzner-cloud-server;
      in {
        gua = {
          prefix = systemSite.hosts.${hostName}.managedNetworks.ipv6.gua |> ip.network.toPrefixGroups;
        };

        ula = {
          prefix = networks.aether.internal.net._meta.network |> ip.network.toPrefixGroups;
          source = networks.aether.internal.net.hosts.collei |> ip.toCompressed;
        };
      };
    };
  };
}
