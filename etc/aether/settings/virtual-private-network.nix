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
  systemd.network = {
    netdevs."25-wg0" = {
      # [NetDev]
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
      };

      # [WireGuard]
      wireguardConfig = {
        ListenPort = 51820;

        # ensure file is readable by `systemd-network` user
        PrivateKeyFile = "/var/lib/wg/x0/p0.key";

        RouteTable = "main";

        FirewallMark = 2370;
      };

      wireguardPeers = [
        # [Peer]
        {
          PublicKeyFile = "/var/lib/wg/x0/p1.pub";
          PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

          AllowedIPs = [
            "fd31::100:2/128"
            "192.168.1.2/32"
          ];

          RouteTable = "main";

          PersistentKeepalive = 25;
        }
        {
          PublicKeyFile = "/var/lib/wg/x0/p2.pub";
          PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

          AllowedIPs = [
            "fd31::100:3/128"
            "192.168.1.3/32"
          ];

          RouteTable = "main";

          PersistentKeepalive = 25;
        }
      ];
    };

    networks."25-wg0" = {
      # [Match]
      matchConfig = {
        Name = "wg0";
      };

      address = [
        # /32 and /128 specifies a single address (smallest
        # possible subnet) for use on this wg peer machine.
        "fd31::100:1/128"
        "192.168.1.1/32"
      ];
    };
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    # iwd takes full control of network configuration and
    # does not allow it to be read-only (or symlinked).
    "/var/lib/wg"
  ];
}
