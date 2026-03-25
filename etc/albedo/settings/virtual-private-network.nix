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
  inherit (lib.attrsets) listToAttrs;
  inherit (lib.extra.net) mkHost;
  inherit (lib.modules) mkMerge;
  inherit (lib.meta) getExe';
in {
  systemd = let
    mkVPN = definitions:
      mkMerge (builtins.map ({
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
                    "192.168.1.1/32"
                    "fd31::100:1/128"
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
                "192.168.1.2/32"
              ];

              networkConfig = {
                DNSDefaultRoute = true;

                DNSOverTLS = "yes";

                DNS = [
                  "192.168.1.1"
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
                  Destination = "192.168.1.1/32";
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
        name = "wg-intranet";
        marker = 1010;
        endpoint = mkHost "192.168.0.10" 51820;
      }
      {
        name = "wg-internet";
        marker = 1020;
        endpoint = mkHost "91.13.165.218" 51820;
      }
    ];
  };

  services.networkd-dispatcher = {
    enable = true;
    rules = {
      vpn-on-demand = {
        onState = ["routable" "carrier"];
        script = ''
          #!${pkgs.runtimeShell}
          if [[ $IFACE == wlan0 ]]; then
              if [[ $ESSID == "heim" ]]; then
                ${getExe' pkgs.systemd "networkctl"} up ${config.systemd.network.netdevs."25-wg-intranet".netdevConfig.Name}
                ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-internet".netdevConfig.Name}
              else
                ${getExe' pkgs.systemd "networkctl"} up ${config.systemd.network.netdevs."25-wg-internet".netdevConfig.Name}
                ${getExe' pkgs.systemd "networkctl"} down ${config.systemd.network.netdevs."25-wg-intranet".netdevConfig.Name}
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
