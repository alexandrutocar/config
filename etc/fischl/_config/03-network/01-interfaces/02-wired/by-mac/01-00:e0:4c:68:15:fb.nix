_: {
  systemd.network = {
    networks = {
      "10-00:e0:4c:68:15:fb" = {
        matchConfig = {
          MACAddress = "00:e0:4c:68:15:fb";
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
              "192.168.1.5/24"
            ]
            ++ [
              # ────────────────────────────────────────────────────────────────────────
              # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
              # ────────────────────────────────────────────────────────────────────────
              # ´               ┌─────────► openssl rand -hex 8 | fold -w4 | paste -sd:
              # ────────────────────────────────────────────────────────────────────────
              "fd4b:ad02:1b77:1:3fd3:2e4b:08dc:1c15/64" # ULA
            ];
        };

        dhcpConfig = {
          Hostname = "Fischl";
          SendHostname = true;
        };
      };
    };
  };
}
