# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀█ █▀█ █ █░█ ▄▀█ ▀█▀ █▀▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █▀▀ █▀▄ █ ▀▄▀ █▀█ ░█░ ██▄
#
# █▄░█ █▀▀ ▀█▀ █░█░█ █▀█ █▀█ █▄▀ █▀
# █░▀█ ██▄ ░█░ ▀▄▀▄▀ █▄█ █▀▄ █░█ ▄█
#
# vpn, wireguard, server...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  # WIREGUARD
  # ---------
  systemd.network = {
    netdevs."25-wg0" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
      };

      wireguardConfig = {
        ListenPort = 51820;

        PrivateKeyFile = "/var/lib/wg/x0/p0.key";
      };

      wireguardPeers = [
        {
          PersistentKeepalive = 25;

          PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

          PublicKeyFile = "/var/lib/wg/x0/p1.pub";

          AllowedIPs = [
            "fd31::100:2/128"
            "192.168.1.2/32"
          ];
        }
        {
          PersistentKeepalive = 25;

          PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

          PublicKeyFile = "/var/lib/wg/x0/p2.pub";

          AllowedIPs = [
            "fd31::100:3/128"
            "192.168.1.3/32"
          ];
        }
      ];
    };

    networks."25-wg0" = {
      matchConfig = {
        Name = "wg0";
      };

      networkConfig = {
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };

      address = [
        # /32 and /128 specifies a single address (smallest
        # possible subnet) for use on this wg peer machine.
        "fd31::100:1/128"
        "192.168.1.1/32"
      ];

      routes = [
        {Destination = "192.168.1.2/32";}
        {Destination = "192.168.1.3/32";}
        {Destination = "fd31::100:2/128";}
        {Destination = "fd31::100:3/128";}
      ];
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      51820
    ];
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    "/var/lib/wg"
  ];
}
