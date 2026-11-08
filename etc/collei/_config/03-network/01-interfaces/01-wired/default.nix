{
  hostName,
  lib,
  ...
}: let
  inherit (lib.strings) toSentenceCase;
in {
  systemd = {
    network = {
      networks = {
        # Network Interface [+]
        "30-enp1s0" = {
          # [Match]
          matchConfig = {
            Name = "enp1s0";
          };

          # [Network]
          networkConfig = {
            Address = ["2a01:4f8:c0c:687::1/64"];
            Gateway = ["fe80::1"];
          };

          routes = [
            {
              Gateway = "fe80::1";
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
