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
#
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
        ListenPort = 50010;

        PrivateKeyFile = "/var/lib/wg/x0/p0.key";
      };

      wireguardPeers = [
        # Laptop
        {
          PersistentKeepalive = 25;

          PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

          PublicKeyFile = "/var/lib/wg/x0/p1.pub";

          AllowedIPs = [
            "fd31::1:2/128"
            "172.16.1.2/32"
          ];
        }
        # Handy
        {
          PersistentKeepalive = 25;

          PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

          PublicKeyFile = "/var/lib/wg/x0/p2.pub";

          AllowedIPs = [
            "fd31::1:3/128"
            "172.16.1.3/32"
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
        # /32 and /128 specifies a single address (the tiniest
        # possible subnet) for use on this wg peer machine.
        "fd31::1:1/128"
        "172.16.1.1/32"
      ];

      routes = [
        {Destination = "fd31::1:2/128";}
        {Destination = "172.16.1.2/32";}

        {Destination = "fd31::1:3/128";}
        {Destination = "172.16.1.3/32";}
      ];
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      50010
    ];
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    "/var/lib/wg"
  ];
}
