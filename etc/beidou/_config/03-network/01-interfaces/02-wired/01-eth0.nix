{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra) ip;
  inherit (lib.strings) toSentenceCase;
in {
  systemd.network = {
    networks = {
      "10-eth0" = let
        gatewayAddresses = with systemSite.router; [ipv4.lan ipv6.ula];

        hostAddresses = with systemSite.hosts.${hostName}; [ipv4.lan ipv6.gua ipv6.ula];

        systemSite = addresses.on-prem.specht;
      in {
        matchConfig = {
          MACAddress = "00:11:22:68:05:7c";
        };

        linkConfig = {
          RequiredForOnline = "routable";
        };

        networkConfig = {
          Address = hostAddresses |> map ip.toCIDR;

          Gateway = gatewayAddresses |> map ip.toCompressed;
        };

        dhcpConfig = {
          Hostname = toSentenceCase hostName;
          SendHostname = true;
        };
      };
    };
  };
}
