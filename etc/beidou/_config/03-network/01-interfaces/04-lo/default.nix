{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) ranges toCIDR;
  inherit (lib.extra.ip.address) singleHostRoute;
  inherit (lib.extra.ip.network) getFirstHost;
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
              ula |> map singleHostRoute;

            loopbackAddresses = map getFirstHost ranges.loopback;
          in
            identityAddresses ++ loopbackAddresses |> map toCIDR;
        };
      };
    };
  };
}
