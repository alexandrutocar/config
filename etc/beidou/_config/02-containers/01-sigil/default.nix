{lib, ...}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCompressed;
  inherit (lib.extra.ip.network) toPrefixGroups;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = {
        # Prefix 2a00:5ba0:8009:5f4*c*::/64 is broken off the ISP-provided fixed
        # 2a00:5ba0:8009:5f4::/60 prefix. A static IPv6 route is added to the
        # router so that 2a00:5ba0:8009:5f4c::/64 can be managed by the host.
        gua.prefix = "2a00:5ba0:8009:5f4c";

        ula = {
          # Prefix fd + a0:9527:68ee is generated randomly. The fourth hextet is
          # derived from the zone name, yielding one deterministic /64 per zone.
          prefix = networks.aether.internal.net._meta.network |> toPrefixGroups;
          source = networks.aether.internal.net.hosts.beidou |> toCompressed;
        };
      };
    };
  };
}
