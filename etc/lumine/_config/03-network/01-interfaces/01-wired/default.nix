_: {
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
            Address =
              [
                "88.198.112.114"
              ]
              ++ [
                "2a01:4f8:c0c:687::/64"
              ];
            Gateway =
              ["172.31.1.1"]
              ++ [
                "fe80::1"
              ];
          };

          routes = [
            {
              Gateway = "172.31.1.1";
              GatewayOnLink = true;
            }
            {
              Gateway = "fe80::1";
            }
          ];

          # [DHCP]
          dhcpConfig = {
            Hostname = "Lumine";
            SendHostname = true;
          };
        };
      };
    };
  };
}
