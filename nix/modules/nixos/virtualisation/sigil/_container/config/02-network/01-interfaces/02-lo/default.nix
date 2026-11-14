{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.ip.address) singleHostRoute;
  inherit (lib.extra.ip.network) getFirstHost;
  inherit (lib.extra.ip) ranges toCIDR;
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
            identityAddresses = (with sigil.self.addresses; [gua ula]) |> filter (a: a != null) |> map singleHostRoute;
            loopbackAddresses = ranges.loopback |> map getFirstHost;
          in
            identityAddresses ++ loopbackAddresses |> map toCIDR;
        };
      };
    };
  };
}
