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
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) mkHost;
  inherit (lib.modules) mkMerge;
  inherit (lib.meta) getExe';
in {
  systemd = let
    mkVPN = definitions:
      mkMerge (map ({
          name,
          marker,
          endpoint,
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
                    "172.16.1.1/32"
                    "fd31::1:1/128"
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
                "172.16.1.2/32"
              ];

              networkConfig = {
                DNSDefaultRoute = true;

                DNSOverTLS = "yes";

                DNS = [
                  "172.16.1.1"
                  # ────────────────────────────────────────────────────────────────────────
                  # TODO: Enable IPv6.
                  # ────────────────────────────────────────────────────────────────────────
                  # "fd31::100:1"
                ];

                Domains = ["~aether.ip" "~."];
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
                  Destination = "172.16.1.1/32";
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
    network = mkVPN [
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
        endpoint = mkHost "212.201.78.87" 50010;
      }
      {
        name = "wg-inter-ipv6";
        marker = 1040;
        endpoint = mkHost "[2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df]" 50010;
      }
    ];
  };

  services.networkd-dispatcher = {
    enable = true;
    rules = {
      vpn-on-demand = {
        onState = ["routable" "carrier"];
        script = let
          internet-ipv4-only-networks = [
            "eduroam"
            "eduroam-cs"
            "eduroam-math"
            "eduroam-stw"
            "eduroam-ukb"
          ];
        in ''
          #!${pkgs.runtimeShell}
          if [[ "$IFACE" == wlan0 ]]; then
            if [[ "$ESSID" == "Specht" ]]; then
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} up ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            elif ${
            if builtins.length internet-ipv4-only-networks > 0
            then builtins.concatStringsSep " || " (map (name: "[[ \"$ESSID\" ==  \"${name}\" ]]") internet-ipv4-only-networks)
            else "false"
          }; then
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} up ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            else
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              ${getExe' pkgs.systemd "networkctl"} up ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            fi
          fi
        '';
      };
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
