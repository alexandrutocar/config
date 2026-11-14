{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.attrsets) attrValues;
  inherit (lib.extra) ip;
  inherit (lib.lists) concatMap filter optionals unique;
  inherit (lib.strings) concatLines concatMapStringsSep;
in let
  # ──────────────────────────────────────────────────────────────────────
  # NOTE: Because VPN is at intersection of communication between all the
  #       peers and their containers, it also serves as the regulator of
  #       inter-host container communication.
  # ──────────────────────────────────────────────────────────────────────
  allowedTrafficFlow = [];

  spokeContainers =
    allowedTrafficFlow
    |> filter (f: f.from.host != f.to.host)
    |> concatMap (f: [f.from f.to])
    |> filter (
      e: e.host != hostName # containers on Beidou (VPN host) can be reached without problem
    )
    |> unique;
in let
  circle = let
    getContainerIPsOnHost = name:
      spokeContainers
      |> filter (e: e.host == name)
      |> map (e: (ip.address.fromString 6 e.addr) |> ip.address.singleHostRoute |> ip.toCIDR);

    getHostIP = name: networks.aether.internal.net.hosts.${name} |> ip.address.singleHostRoute |> ip.toCIDR;
  in {
    albedo = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p1.pre";

      PublicKeyFile = "/var/lib/wg/x0/p1.pub";

      AllowedIPs = [
        (getHostIP "albedo")
      ];
    };
    collei = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p3.pre";

      PublicKeyFile = "/var/lib/wg/x0/p3.pub";

      AllowedIPs =
        [
          (getHostIP "collei")
        ]
        ++ getContainerIPsOnHost "collei";
    };
    fischl = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p4.pre";

      PublicKeyFile = "/var/lib/wg/x0/p4.pub";

      AllowedIPs =
        [
          (getHostIP "fischl")
        ]
        ++ getContainerIPsOnHost "fischl";
    };
    keqing = {
      PersistentKeepalive = 25;

      PresharedKeyFile = "/var/lib/wg/x0/p2.pre";

      PublicKeyFile = "/var/lib/wg/x0/p2.pub";

      AllowedIPs = [
        (getHostIP "keqing")
      ];
    };
  };
in {
  networking = {
    nftables = {
      tables = {
        sigil-containers = {
          family = "inet";
          content = let
            hasSpokeContainers = spokeContainers != [];
            indent = map (line: "  " + line);
            flowRule = f: "ip6 saddr ${f.from.addr} ip6 daddr ${f.to.addr} ${f.proto} dport { ${concatMapStringsSep ", " toString f.ports} } counter accept";
          in
            concatLines (
              optionals hasSpokeContainers [
                "set spoke-containers {"
                "  type ipv6_addr"
                "  elements = { ${concatMapStringsSep ", " (e: e.addr) spokeContainers} }"
                "}"
                ""
              ]
              ++ ["chain forward {"]
              ++ indent (
                [
                  "type filter hook forward priority filter; policy accept;"
                  ""
                  "ct state established,related accept"
                ]
                ++ map flowRule allowedTrafficFlow
                ++ optionals hasSpokeContainers [
                  ""
                  "# anything else to or from a spoke container is not allowed"
                  "ip6 saddr @spoke-containers counter drop"
                  "ip6 daddr @spoke-containers counter drop"
                ]
              )
              ++ ["}"]
              ++ optionals hasSpokeContainers (
                [
                  ""
                  "chain input {"
                ]
                ++ indent [
                  "type filter hook input priority filter; policy accept;"
                  ""
                  "ct state established,related accept"
                  ""
                  "# spoke containers may not open connections to the VPN host itself"
                  "ip6 saddr @spoke-containers counter drop"
                ]
                ++ ["}"]
              )
            );
        };
      };
    };
  };

  systemd = {
    network = let
      Name = "wg0";
      wireguardPeers = attrValues circle;
    in {
      netdevs = {
        "10-wg0" = {
          inherit wireguardPeers;

          netdevConfig = {
            inherit Name;

            Kind = "wireguard";
          };

          wireguardConfig = {
            ListenPort = 50010;

            PrivateKeyFile = "/var/lib/wg/x0/p0.key";
          };
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

          routes = wireguardPeers |> concatMap (p: p.AllowedIPs) |> map (Destination: {inherit Destination;});
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
