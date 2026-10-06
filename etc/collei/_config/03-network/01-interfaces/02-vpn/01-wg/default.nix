{lib, ...}: let
  inherit (lib.extra.net) mkHost;
in {
  systemd = {
    network = let
      name = "wg0";
      marker = 1010;
      endpoint = mkHost "[2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df]" 50010;
    in {
      netdevs = {
        "25-${name}" = {
          netdevConfig = {
            Name = name;
            Kind = "wireguard";
          };

          wireguardConfig = {
            PrivateKeyFile = "/var/lib/wg/x0/p3.key";
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
            "fda0:9527:68ee:4f8a:46a1:b595:357f:c251/128"
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
    };
  };

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    "/var/lib/wg"
  ];
}
