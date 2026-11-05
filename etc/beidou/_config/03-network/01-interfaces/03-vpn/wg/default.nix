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
{lib, ...}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCIDR;
  inherit (lib.extra.ip.address) singleHostRoute;
in let
  circle = {
    beidou = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

      PublicKeyFile = "/var/lib/wg/x0/p1.pub";

      AllowedIPs = [
        (networks.aether.internal.net.hosts.albedo |> singleHostRoute |> toCIDR)
      ];
    };
    collei = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p3.pre";

      PublicKeyFile = "/var/lib/wg/x0/p3.pub";

      AllowedIPs = [
        (networks.aether.internal.net.hosts.collei |> singleHostRoute |> toCIDR)
      ];
    };
    fischl = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p4.pre";

      PublicKeyFile = "/var/lib/wg/x0/p4.pub";

      AllowedIPs = [
        (networks.aether.internal.net.hosts.fischl |> singleHostRoute |> toCIDR)
      ];
    };
    keqing = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

      PublicKeyFile = "/var/lib/wg/x0/p2.pub";

      AllowedIPs = [
        (networks.aether.internal.net.hosts.keqing |> singleHostRoute |> toCIDR)
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
            circle.beidou
            circle.collei
            circle.fischl
            circle.keqing
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
              Destination = networks.aether.internal.net.hosts.albedo |> singleHostRoute |> toCIDR;
            }
            {
              Destination = networks.aether.internal.net.hosts.collei |> singleHostRoute |> toCIDR;
            }
            {
              Destination = networks.aether.internal.net.hosts.fischl |> singleHostRoute |> toCIDR;
            }
            {
              Destination = networks.aether.internal.net.hosts.keqing |> singleHostRoute |> toCIDR;
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
