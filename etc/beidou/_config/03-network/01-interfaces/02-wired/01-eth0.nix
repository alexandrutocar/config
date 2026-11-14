{
  hostName,
  self,
  lib,
  ...
}: let
  inherit (lib.alias) addresses;
  inherit (lib.extra.ip) toCIDR toCompressed;
  inherit (lib.strings) toSentenceCase;
in let
  containers.beidou = {
    inherit (self.nixosConfigurations.beidou.config.services.sigil.settings.containers.intra) cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a;
  };
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
          DNSDefaultRoute = true;

          DNS = [
            (containers.beidou.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses.ula |> toCompressed)
          ];

          Domains =
            [
              "~intra.net.internal"
              "~hosts.net.internal"
            ]
            ++ ["~."];

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
