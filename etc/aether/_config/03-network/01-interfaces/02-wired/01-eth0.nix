_: {
  systemd.network = {
    networks = {
      "10-eth0" = {
        matchConfig = {
          MACAddress = "00:11:22:68:05:7c";
        };

        linkConfig = {
          RequiredForOnline = "routable";
        };

        networkConfig = {
          Gateway =
            [
              "192.168.1.1"
            ]
            ++ [
              "fd4b:ad02:1b77:1:e228:6dff:fe1d:8a9c" # ULA
            ];

          Address =
            [
              "192.168.1.2/24"
            ]
            ++ [
              "fd4b:ad02:1b77:1:0020:61fc:3462:bf01/64" # ULA
              "2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df/64" # WAN
            ];
        };

        dhcpConfig = {
          Hostname = "Aether";
          SendHostname = true;
        };
      };
    };
  };
}
