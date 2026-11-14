{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra.ip) ranges toCIDR toCompressed;
  inherit (lib.extra.ip.network) getFirstHost;
  inherit (lib.extra.trivial) pipeline;
  inherit (lib.strings) toSentenceCase;
in {
  systemd = {
    network = {
      networks = {
        "30-enp1s0" = let
          gatewayAddresses = let
            ll = (builtins.head ranges.ipv6.linkLocal) |> getFirstHost;
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
            Address = hostAddresses |> map toCIDR;

            Gateway = gatewayAddresses |> map toCompressed;
          };

          routes = gatewayAddresses |> map (pipeline [toCompressed (Gateway: {inherit Gateway;})]);

          dhcpConfig = {
            Hostname = toSentenceCase hostName;
            SendHostname = true;
          };
        };
      };
    };
  };
}
