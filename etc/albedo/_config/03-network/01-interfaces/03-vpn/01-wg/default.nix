{
  self,
  lib,
  ...
}: let
  inherit (lib.alias) addresses networks;
  inherit (lib.extra) ip url;
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
                    (networks.aether.internal.net._meta.network |> ip.toCIDR)
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
                (networks.aether.internal.net.hosts.albedo |> ip.address.singleHostRoute |> ip.toCIDR)
              ];

              networkConfig = {
                DNSDefaultRoute = true;

                DNS = [
                  (containers.beidou.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses.ipv6.ula |> ip.toCompressed)
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
                  Destination = networks.aether.internal.net._meta.network |> ip.toCIDR;
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
    network = let
      remoteSite = addresses.on-prem.specht;
    in
      mkWireGuardVPN [
        {
          name = "wg-intra-ipv4";
          marker = 1010;
          endpoint = url.mkInterface remoteSite.hosts.beidou.ipv4.lan 50010;
        }
        {
          name = "wg-intra-ipv6";
          marker = 1020;
          endpoint = url.mkInterface remoteSite.hosts.beidou.ipv6.ula 50010;
        }
        {
          name = "wg-inter-ipv4";
          marker = 1030;
          endpoint = url.mkInterface remoteSite.router.ipv4.wan 50010;
        }
        {
          name = "wg-inter-ipv6";
          marker = 1040;
          endpoint = url.mkInterface remoteSite.hosts.beidou.ipv6.gua 50010;
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
