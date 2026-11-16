{
  sigil,
  lib,
  ...
}: let
  inherit (lib.attrsets) attrValues;
  inherit (lib.extra) ip;
  inherit (lib.lists) optional;
in {
  systemd = {
    network = {
      networks = {
        "10-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address = let
            identityAddresses = with sigil.self.addresses.ipv6; [ula] ++ optional (gua != null) gua;
            loopbackAddresses = ip.ranges.loopback |> map ip.network.getFirstHost;
          in
            identityAddresses ++ loopbackAddresses |> map ip.toCIDR;

          # Extras are deprecated (PreferredLifetime=0): they accept traffic
          # but are never chosen as source addresses.
          addresses = let
            inherit (sigil.self.addresses.ipv6.extra) gua ula;
          in
            (attrValues ula ++ attrValues gua)
            |> map (address: {
              Address = address |> ip.toCIDR;
              PreferredLifetime = 0;
            });
        };
      };
    };
  };
}
