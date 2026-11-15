{
  sigil,
  lib,
  ...
}: let
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
            identityAddresses = (with sigil.self.addresses.ipv6; [ula] ++ optional (gua != null) gua) |> map ip.address.singleHostRoute;
            loopbackAddresses = ip.ranges.loopback |> map ip.network.getFirstHost;
          in
            identityAddresses ++ loopbackAddresses |> map ip.toCIDR;
        };
      };
    };
  };
}
