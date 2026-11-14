{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra.ip) toCIDR toCompressed;
  inherit (lib.strings) toSentenceCase;
in {
  systemd.network = {
    networks = {
      "25-wlan0" = let
        gatewayAddresses = with systemSite.router; [ipv4.lan ipv6.ula];

        hostAddresses = with systemSite.hosts.${hostName}; [ipv4.lan ipv6.ula];

        systemSite = addresses.on-prem.specht;
      in {
        matchConfig = {
          Type = "wlan";
          SSID = "Specht";
        };

        linkConfig = {
          RequiredForOnline = "routable";
        };

        networkConfig = {
          Address = hostAddresses |> map toCIDR;

          Gateway = gatewayAddresses |> map toCompressed;
        };

        dhcpConfig = {
          Hostname = toSentenceCase hostName;
          SendHostname = true;
        };
      };
    };
  };
}
