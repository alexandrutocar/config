{
  self,
  lib,
  ...
}: let
  inherit (lib.alias) addresses networks;
  inherit (lib.extra.ip) toCIDR toCompressed;
  inherit (lib.extra.ip.address) singleHostRoute;
  inherit (lib.extra.url) mkInterface;
in let
  containers.beidou = {
    inherit (self.nixosConfigurations.beidou.config.services.sigil.settings.containers.intra) cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a;
  };
in {
  systemd = {
    network = let
      name = "wg0";
      marker = 1010;
      endpoint = mkInterface remoteSite.router.ipv4.wan 50010;
      remoteSite = addresses.on-prem.specht;
    in {
      netdevs = {
        "25-${name}" = {
          netdevConfig = {
            Name = name;
            Kind = "wireguard";
          };

          wireguardConfig = {
            PrivateKeyFile = "/var/lib/wg/x0/p4.key";
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
            (networks.aether.internal.net.hosts.fischl |> singleHostRoute |> toCIDR)
          ];

          networkConfig = {
            DNSDefaultRoute = true;

            DNS = [
              (containers.beidou.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses.ula |> toCompressed)
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
    };
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    "/var/lib/wg"
  ];
}
