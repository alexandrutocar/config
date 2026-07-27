{sigil, ...}: let
  mkLCLinkName = bid: mid: "lc-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";
in {
  systemd = {
    network = {
      networks = sigil.self.links.lib.bridge.mapToAttrs (bridge: let
        Name = mkLCLinkName bridge.bid sigil.self.mid;

        selfIsA = sigil.self.mid < bridge.port.mid;
        selfLL =
          if selfIsA
          then "fe80::a"
          else "fe80::b";
        peerLL =
          if selfIsA
          then "fe80::b"
          else "fe80::a";
      in {
        "10-${Name}" = {
          matchConfig = {
            inherit Name;
          };
          networkConfig = {
            IPv6LinkLocalAddressGenerationMode = "none";
          };
          address = ["${selfLL}/64"];
          routes = [
            {
              Destination = "${bridge.port.addresses.ula}/128";
              Gateway = peerLL;
              GatewayOnLink = true;
              PreferredSource = sigil.self.addresses.ula;
            }
          ];
        };
      });
    };
  };
}
