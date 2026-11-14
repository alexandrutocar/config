{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra) ip;
in {
  systemd = {
    network = {
      networks = {
        "00-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address = let
            identityAddresses = let
              ula = [
                networks.aether.internal.net.hosts.${hostName}
              ];
            in
              ula |> map ip.address.singleHostRoute;

            loopbackAddresses = map ip.network.getFirstHost ip.ranges.loopback;
          in
            identityAddresses ++ loopbackAddresses |> map ip.toCIDR;
        };
      };
    };
  };
}
