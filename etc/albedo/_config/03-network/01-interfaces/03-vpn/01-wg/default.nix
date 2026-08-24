# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀█ █▀█ █ █░█ ▄▀█ ▀█▀ █▀▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █▀▀ █▀▄ █ ▀▄▀ █▀█ ░█░ ██▄
#
# █▄░█ █▀▀ ▀█▀ █░█░█ █▀█ █▀█ █▄▀ █▀
# █░▀█ ██▄ ░█░ ▀▄▀▄▀ █▄█ █▀▄ █░█ ▄█
#
# vpn, wireguard, client...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.net) mkHost;
  inherit (lib.modules) mkMerge;
in {
  systemd = let
    mkWireGuardVPN = definitions:
      mkMerge (map ({
          endpoint,
          marker,
          name,
        }: {
          netdevs = {
            "25-${name}" = {
              netdevConfig = {
                Kind = "wireguard";
                Name = name;
              };

              wireguardConfig = {
                PrivateKeyFile = "/var/lib/wg/x0/p1.key";
                FirewallMark = marker;
                RouteTable = "off";
              };

              wireguardPeers = [
                {
                  PresharedKeyFile = "/var/lib/wg/x0/p0.pre";

                  PublicKeyFile = "/var/lib/wg/x0/p0.pub";

                  Endpoint = endpoint;

                  AllowedIPs = [
                    "fda0:9527:68ee::/48"
                  ];

                  RouteTable = "off";

                  PersistentKeepalive = 25;
                }
              ];
            };
          };

          networks = {
            "25-${name}" = {
              matchConfig = {
                Name = name;
              };

              address = [
                "fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128"
              ];

              networkConfig = {
                DNSDefaultRoute = true;

                DNS = [
                  "fda0:9527:68ee:f1b6:d826:828b:d703:cf4b"
                ];

                Domains =
                  [
                    "~intra.net.internal"
                    "~hosts.net.internal"
                  ]
                  ++ ["~."];
              };

              routingPolicyRules = [
                {
                  Family = "both";
                  Table = "main";
                  SuppressPrefixLength = 0;
                  Priority = 10;
                }
                {
                  Family = "both";
                  InvertRule = true;
                  FirewallMark = marker;
                  Table = marker;
                  Priority = 11;
                }
              ];

              routes = [
                {
                  Destination = "fda0:9527:68ee::/48";
                  Table = marker;
                  Scope = "link";
                }
              ];

              linkConfig = {
                ActivationPolicy = "manual";
                RequiredForOnline = false;
              };
            };
          };
        })
        definitions);
  in {
    network = mkWireGuardVPN [
      {
        name = "wg-intra-ipv4";
        marker = 1010;
        endpoint = mkHost "192.168.1.2" 50010;
      }
      {
        name = "wg-intra-ipv6";
        marker = 1020;
        endpoint = mkHost "[fd4b:ad02:1b77:1:0020:61fc:3462:bf01]" 50010;
      }
      {
        name = "wg-inter-ipv4";
        marker = 1030;
        endpoint = mkHost "212.201.76.52" 50010;
      }
      {
        name = "wg-inter-ipv6";
        marker = 1040;
        endpoint = mkHost "[2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df]" 50010;
      }
    ];
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    # iwd takes full control of network configuration and
    # does not allow it to be read-only (or symlinked).
    "/var/lib/wg"
  ];
}
