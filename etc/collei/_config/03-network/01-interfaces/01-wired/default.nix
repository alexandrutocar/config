{
  hostName,
  lib,
  ...
}: let
  inherit (lib.extra.ip) ranges toCompressed;
  inherit (lib.extra.ip.network) getFirstHost;
  inherit (lib.strings) toSentenceCase;
in {
  systemd = {
    network = {
      networks = {
        # Network Interface [+]
        "30-enp1s0" = let
          defaultGateway = (builtins.head ranges.ipv6.linkLocal) |> getFirstHost |> toCompressed;
        in {
          # [Match]
          matchConfig = {
            Name = "enp1s0";
          };

          # [Network]
          networkConfig = {
            Address = ["2a01:4f8:c0c:687::1/64"];

            Gateway = [defaultGateway];
          };

          routes = [
            {
              Gateway = defaultGateway;
            }
          ];

          # [DHCP]
          dhcpConfig = {
            Hostname = toSentenceCase hostName;
            SendHostname = true;
          };
        };
      };
    };
  };
}
