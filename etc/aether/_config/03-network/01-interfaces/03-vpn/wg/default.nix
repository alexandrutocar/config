# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀█ █▀█ █ █░█ ▄▀█ ▀█▀ █▀▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █▀▀ █▀▄ █ ▀▄▀ █▀█ ░█░ ██▄
#
# █▄░█ █▀▀ ▀█▀ █░█░█ █▀█ █▀█ █▄▀ █▀
# █░▀█ ██▄ ░█░ ▀▄▀▄▀ █▄█ █▀▄ █░█ ▄█
#
# TAGS: VPN, WireGuard
#
# ────────────────────────────────────────────────────────────────────────
_: let
  circle = {
    aether = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

      PublicKeyFile = "/var/lib/wg/x0/p1.pub";

      AllowedIPs = [
        "fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128"
      ];
    };
    keqing = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

      PublicKeyFile = "/var/lib/wg/x0/p2.pub";

      AllowedIPs = [
        "fda0:9527:68ee:4f8a:afbf:7002:aa5f:a363/128"
      ];
    };
    lumine = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p3.pre";

      PublicKeyFile = "/var/lib/wg/x0/p3.pub";

      AllowedIPs = [
        "fda0:9527:68ee:4f8a:46a1:b595:357f:c251/128"
      ];
    };
  };
in {
  systemd = {
    network = let
      Name = "wg0";
    in {
      netdevs = {
        "10-wg0" = {
          netdevConfig = {
            inherit Name;

            Kind = "wireguard";
          };

          wireguardConfig = {
            ListenPort = 50010;

            PrivateKeyFile = "/var/lib/wg/x0/p0.key";
          };

          wireguardPeers = [
            circle.aether
            circle.keqing
            circle.lumine
          ];
        };
      };
      networks = {
        "10-wg0" = {
          matchConfig = {
            inherit Name;
          };

          networkConfig = {
            IPv6Forwarding = true;
          };

          routes = [
            {
              Destination = "fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128";
            }
            {
              Destination = "fda0:9527:68ee:4f8a:afbf:7002:aa5f:a363/128";
            }
            {
              Destination = "fda0:9527:68ee:4f8a:46a1:b595:357f:c251/128";
            }
          ];
        };
      };
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      50010 # WireGuard
    ];
  };

  environment.persistence."/state".directories = [
    "/var/lib/wg"
  ];
}
