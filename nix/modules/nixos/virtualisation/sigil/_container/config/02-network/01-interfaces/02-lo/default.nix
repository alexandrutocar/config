{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.lists) filter;
in {
  systemd = {
    network = {
      networks = {
        "10-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address = let
            identityAddresses = (with sigil.self.addresses.ipv6; [gua ula]) |> filter (a: a != null) |> map ip.address.singleHostRoute;
            loopbackAddresses = ip.ranges.loopback |> map ip.network.getFirstHost;
          in
            identityAddresses ++ loopbackAddresses |> map ip.toCIDR;
        };
      };
    };
  };
}
