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
{
  self,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCIDR;
  inherit (lib.extra.ip.address) singleHostRoute;
  inherit (lib.extra.net.url.authority) mkAuthority;
  inherit (lib.modules) mkMerge;
in let
  containers.beidou = {
    inherit (self.nixosConfigurations.beidou.config.services.sigil.settings.containers.intra) cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a;
  };
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
                    (networks.aether.internal.net._meta.network |> toCIDR)
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
                (networks.aether.internal.net.hosts.albedo |> singleHostRoute |> toCIDR)
              ];

              networkConfig = {
                DNSDefaultRoute = true;

                DNS = [
                  containers.beidou.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses.ula
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
                  Destination = networks.aether.internal.net._meta.network |> toCIDR;
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
        endpoint = mkAuthority "192.168.1.2" 50010 {};
      }
      {
        name = "wg-intra-ipv6";
        marker = 1020;
        endpoint = mkAuthority "fd4b:ad02:1b77:1:0020:61fc:3462:bf01" 50010 {};
      }
      {
        name = "wg-inter-ipv4";
        marker = 1030;
        endpoint = mkAuthority "212.201.75.101" 50010 {};
      }
      {
        name = "wg-inter-ipv6";
        marker = 1040;
        endpoint = mkAuthority "2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df" 50010 {};
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
