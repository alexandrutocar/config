_: {
  systemd.network = {
    networks = {
      "10-00:11:22:68:44:03" = {
        matchConfig = {
          MACAddress = "00:11:22:68:44:03";
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
              "fd60:a0ff:34b3:1::1" # ULA
            ];

          Address =
            [
              "192.168.1.3/24"
            ]
            ++ [
              # ────────────────────────────────────────────────────────────────────────
              # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
              # ────────────────────────────────────────────────────────────────────────
              # ´               ┌─────────► openssl rand -hex 8 | fold -w4 | paste -sd:
              # ────────────────────────────────────────────────────────────────────────
              "fd60:a0ff:34b3:1:3168:6440:959b:1aca/64" # ULA
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
