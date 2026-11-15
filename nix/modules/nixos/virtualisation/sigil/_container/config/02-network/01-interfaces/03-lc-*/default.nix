{
  sigil,
  lib,
  ...
}: let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.extra) ip;
  inherit (lib.lists) optional;

  mkLCLinkName = bid: mid: "lc-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";
in {
  systemd = {
    network = {
      networks = sigil.self.links.lib.bridge.mapToAttrs (bridge: let
        Name = mkLCLinkName bridge.bid sigil.self.mid;

        selfIsA = sigil.self.mid < bridge.port.mid;
        selfLL =
          if selfIsA
          then sigil.linkLocal.peerA
          else sigil.linkLocal.peerB;
        peerLL =
          if selfIsA
          then sigil.linkLocal.peerB
          else sigil.linkLocal.peerA;
      in {
        "10-${Name}" = {
          matchConfig = {
            inherit Name;
          };
          networkConfig = {
            IPv6LinkLocalAddressGenerationMode = "none";
          };
          address = [(selfLL |> ip.toCIDR)];
          routes = optional (bridge.port.addresses.ipv6.ula != null) (
            {
              Destination = bridge.port.addresses.ipv6.ula |> ip.toCIDR;
              Gateway = peerLL |> ip.toCompressed;
              GatewayOnLink = true;
            }
            // optionalAttrs (sigil.self.addresses.ipv6.ula != null) {
              PreferredSource = sigil.self.addresses.ipv6.ula |> ip.toCompressed;
            }
          );
        };
      });
    };
  };
}
