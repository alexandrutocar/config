lib: let
  inherit (lib.extra) ip;
in let
  AS24940 = {
    DE-HETZNER-20071010 = ip.network.fromCIDR 6 "2a01:4f8::/32";
    HOA-EU-DC = ip.network.fromCIDR 4 "2.31.0.0/16";
  };
in {
  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Hardcoded as default gateway for all Hetzner's servers.
  # ────────────────────────────────────────────────────────────────────────
  defaultGateway = {
    ipv4 = {
      lan = ip.address.fromString 4 "172.31.1.1/32";
    };
    ipv6 = {
      ll = (builtins.head ip.ranges.ipv6.linkLocal) |> ip.network.getFirstHost;
    };
  };

  hosts = {
    collei = let
      ipv6 = {
        gua = ip.network.subnetFromBits AS24940.DE-HETZNER-20071010 64 "0:0:c0c:687::";
      };
    in {
      managedNetworks = {
        inherit ipv6;
      };

      ipv4 = {
        wan = ip.network.hostAddress AS24940.HOA-EU-DC "0.0.148.63";
      };

      ipv6 = {
        gua = ip.network.hostAddress ipv6.gua "::1";
      };
    };
  };
}
