{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.ip) toCIDR toCompressed;
  inherit (lib.attrsets) optionalAttrs;
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
          address = [(toCIDR selfLL)];
          routes = optional (bridge.port.addresses.ula != null) (
            {
              Destination = toCIDR bridge.port.addresses.ula;
              Gateway = toCompressed peerLL;
              GatewayOnLink = true;
            }
            // optionalAttrs (sigil.self.addresses.ula != null) {
              PreferredSource = toCompressed sigil.self.addresses.ula;
            }
          );
        };
      });
    };
  };
}
