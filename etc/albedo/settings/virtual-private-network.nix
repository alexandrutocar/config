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
  inherit (lib.custom.net) mkHost;
in {
  systemd.network = {
    netdevs."25-wg0" = {
      # [NetDev]
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
      };

      # [WireGuard]
      wireguardConfig = {
        PrivateKeyFile = "/var/lib/wg/_x0/p1.key";

        FirewallMark = 2370;
        RouteTable = "off";
      };
      wireguardPeers = [
        # [Peer]
        {
          PublicKeyFile = "/var/lib/wg/_x0/p0.pub";
          PresharedKeyFile = "/var/lib/wg/_x0/p0.pre";

          Endpoint = mkHost "aether.ns.ueuie.dev" 53280;

          AllowedIPs = ["192.168.0.0/24"];
          RouteTable = "off";

          PersistentKeepalive = 21;
        }
      ];
    };

    networks."25-wg0" = {
      # [Match]
      matchConfig = {
        Name = "wg0";
      };

      address = [
        "10.200.200.2/24"
      ];

      # [Network]
      networkConfig = {
        DNSDefaultRoute = true;

        DNS = [
          "192.168.0.10"
          # ────────────────────────────────────────────────────────────────────────
          # TODO: Enable IPv6.
          # ────────────────────────────────────────────────────────────────────────
          # "fd31::100:10"
        ];

        Domains = ["~aether.ip" "~."];

        DNSOverTLS = "yes";
      };

      routingPolicyRules = [
        # [RoutingPolicyRule]
        {
          Family = "both";
          Table = "main";
          SuppressPrefixLength = 0;
          Priority = 10;
        }
        # [RoutingPolicyRule]
        {
          Family = "both";
          InvertRule = true;
          FirewallMark = 2370;
          Table = 2370;
          Priority = 11;
        }
      ];

      # [Route]
      routes = [
        {
          Destination = "192.168.0.0/24";
          Table = 2370;
          Scope = "link";
        }
      ];

      # [Link]
      linkConfig = {
        ActivationPolicy = "manual";
        RequiredForOnline = false;
      };
    };
  };

  services.networkd-dispatcher = {
    enable = true;
    rules = {
      wg0-bring-up-on-demand = {
        onState = ["routable" "carrier"];
        script = ''
          #!${pkgs.runtimeShell}
          if [[ $IFACE == wlan0 ]]; then
              if [[ $ESSID == ${config.systemd.network.networks."25-wlan0".matchConfig.SSID} ]]; then
                ${pkgs.systemd}/bin/networkctl down ${config.systemd.network.netdevs."25-wg0".netdevConfig.Name}
                exit 0
              fi
              ${pkgs.systemd}/bin/networkctl up ${config.systemd.network.netdevs."25-wg0".netdevConfig.Name}
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
