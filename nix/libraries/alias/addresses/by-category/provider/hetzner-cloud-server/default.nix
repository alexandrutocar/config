lib: let
  inherit (lib.extra) ip;
in let
  AS24940 = {
    DE-HETZNER-20071010 = ip.network.fromCIDR 6 "2a01:4f8::/32";
  };
in {
  hosts = {
    collei = let
      ipv6 = {
        gua = ip.network.subnetFromBits AS24940.DE-HETZNER-20071010 64 "0:0:c0c:687::";
      };
    in {
      managedNetworks = {
        inherit ipv6;
      };

      ipv6 = {
        gua = ip.network.hostAddress ipv6.gua "::1";
      };
    };
  };
}
