{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra) ip;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.strings) toSentenceCase;
in {
  systemd = {
    network = {
      networks = {
        "30-enp1s0" = let
          gatewayAddresses = with systemSite.defaultGateway; [
            ipv4.lan
            ipv6.ll
          ];

          hostAddresses = with systemSite.hosts.${hostName}; [ipv4.wan ipv6.gua];

          systemSite = addresses.provider.hetzner-cloud-server;
        in {
          matchConfig = {
            Name = "enp1s0";
          };

          networkConfig = {
            Address = hostAddresses |> map ip.toCIDR;

            Gateway = gatewayAddresses |> map ip.toCompressed;
          };

          routes =
            gatewayAddresses
            |> mapPipeline [
              ip.toCompressed
              (Gateway: {
                inherit Gateway;
                GatewayOnLink = true;
              })
            ];

          dhcpConfig = {
            Hostname = toSentenceCase hostName;
            SendHostname = true;
          };
        };
      };
    };
  };
}
