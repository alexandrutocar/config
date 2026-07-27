_: {
  systemd.network = {
    networks = {
      # Network Interface [+]
      "25-wlan0" = {
        # [Match]
        matchConfig = {
          Type = "wlan";
          SSID = "Specht";
        };

        # [Link]
        linkConfig = {
          RequiredForOnline = "routable";
        };

        # [Network]
        networkConfig = {
          Address =
            ["192.168.1.3/24"]
            ++ [
              "fd4b:ad02:1b77:1:e567:df0a:5754:97ed/64" # ULA
            ];

          Gateway =
            ["192.168.1.1"]
            ++ [
              "fd4b:ad02:1b77:1:e228:6dff:fe1d:8a9c" # ULA
            ];
        };

        # [DHCP]
        dhcpConfig = {
          Hostname = "Albedo";
          SendHostname = true;
        };
      };
    };
  };
}
