{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra) ip;
  inherit (lib.extra.trivial) pipeline;
  inherit (lib.strings) toSentenceCase;
in {
  systemd = {
    network = {
      networks = {
        "30-enp1s0" = let
          gatewayAddresses = let
            ll = (builtins.head ip.ranges.ipv6.linkLocal) |> ip.network.getFirstHost;
          in [
            ll
          ];

          hostAddresses = with systemSite.hosts.${hostName}; [ipv6.gua];

          systemSite = addresses.provider.hetzner-cloud-server;
        in {
          matchConfig = {
            Name = "enp1s0";
          };

          networkConfig = {
            Address = hostAddresses |> map ip.toCIDR;

            Gateway = gatewayAddresses |> map ip.toCompressed;
          };

          routes = gatewayAddresses |> map (pipeline [ip.toCompressed (Gateway: {inherit Gateway;})]);

          dhcpConfig = {
            Hostname = toSentenceCase hostName;
            SendHostname = true;
          };
        };
      };
    };
  };
}
