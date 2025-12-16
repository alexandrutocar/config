# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, wireless, wired...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/settings/net.nix);

  networking = {
    # WIRELESS
    # --------
    wireless.iwd = {
      settings = {
        General = {
          # ────────────────────────────────────────────────────────────────────────
          # TODO: Harden `iwd` by letting the daemon encrypt network configuraions.
          # - Enable hybrid encryption.
          # - Generate `iwd` secret passphrase/password and back it up.
          # - Create `iwd` credential (/etc/credstore/iwd.secret).
          # ────────────────────────────────────────────────────────────────────────
          # SystemdEncrypt = "iwd";
        };
      };
    };

    useNetworkd = true;
    enableIPv6 = false;
  };

  # SYSTEMD NETWORK
  # ------- -------
  systemd.network = {
    networks = {
      # Network Interface [+]

      "25-wlp2s0" = {
        # [Match]
        matchConfig = {
          Type = "wlan";
          SSID = "heim";
        };

        # [Link]
        linkConfig = {
          RequiredForOnline = "routable";
        };

        # [Network]
        networkConfig = {
          Address = ["192.168.0.10/24" "fe80::9ecc:83ff:fec8:1010/64"];
          Gateway = ["192.168.0.1" "fe80::9ecc:83ff:fec8:46aa"];

          # DNS = [
          #   # "192.168.0.10"
          #   # ────────────────────────────────────────────────────────────────────────
          #   # TODO: Enable IPv6 when IPv6 for containers is restored.
          #   # ────────────────────────────────────────────────────────────────────────
          #   # "fe80::9ecc:83ff:fec8:1010"
          # ];
          # DNSDefaultRoute = true;

          # Domains = ["~aether.ip" "~."];
          # DNSOverTLS = "yes";
        };
      };

      # "25-br-x0" = {
      #   # [Match]
      #   matchConfig = {
      #     Name = "br-x0";
      #   };

      #   # [Network]
      #   networkConfig = {
      #     Address = [
      #       "10.0.0.1/24" # max. 253 container addresses
      #       # "fd00:0:0:0::1/120" # max. 253 container addresses
      #     ];

      #     DHCPServer = "yes";
      #   };

      #   # [DHCPServerConfig]
      #   dhcpServerConfig = {
      #     PoolOffset = 2;
      #     PoolSize = 253;
      #     DefaultLeaseTimeSec = "1h";
      #     MaxLeaseTimeSec = "12h";
      #   };
      # };

      "25-br-x1" = {
        # [Match]
        matchConfig = {
          Name = "br-x1";
        };

        # [Network]
        networkConfig = {
          Address = [
            "10.0.1.1/24" # max. 253 container addresses
            # "fd00:0:0:1::1/120" # max. 253 container addresses
          ];

          DHCPServer = "yes";
        };

        # [DHCPServerConfig]
        dhcpServerConfig = {
          PoolOffset = 2;
          PoolSize = 253;
          DefaultLeaseTimeSec = "1h";
          MaxLeaseTimeSec = "12h";
        };
      };
    };
    netdevs = {
      # "25-br-x0" = {
      #   # [NetDev]
      #   netdevConfig = {
      #     Name = "br-x0";
      #     Kind = "bridge";
      #   };
      # };
      "25-br-x1" = {
        # [NetDev]
        netdevConfig = {
          Name = "br-x1";
          Kind = "bridge";
        };
      };
    };
  };

  # Does not work as another rule
  # takes precedence (implicitly).
  # systemd.network.networks = {
  #   "90-container-x1-ve-wkm" = {
  #     # [Match]
  #     matchConfig = {
  #       Kind = "veth";
  #       Name = "ve-x1-wkm";
  #     };

  #     # [Link]
  #     linkConfig = {
  #       RequiredForOnline = false;
  #     };

  #     # [Network]
  #     networkConfig = {
  #       LinkLocalAddressing = true;

  #       Address = "0.0.0.0/28";

  #       DHCPServer = true;

  #       IPMasquerade = "both";

  #       LLDP = true;

  #       EmitLLDP = "customer-bridge";
  #       IPv6AcceptRA = false;
  #       IPv6SendRA = true;

  #       # DNS
  #       DNS = [
  #         "192.168.0.10"
  #       ];

  #       DNSDefaultRoute = true;

  #       Domains = ["~aether.ip" "~."];
  #       DNSOverTLS = true;
  #     };

  #     extraConfig = ''
  #       [DHCPServer]
  #       PersistLeases=runtime
  #     '';
  #   };
  # };

  # services.dnsmasq = {
  #   enable = true;
  #   settings = {
  #     bind-interfaces = true;
  #     domain-needed = true;
  #     bogus-priv = true;
  #   };
  #   configFile = pkgs.writeTextFile "dnsmasq.conf" ''
  #     interface=br-x0
  #   '';
  # };

  # CERTIFICATE
  # -----------
  security.pki.certificates = [
    (builtins.readFile (self + /.pki/ca/root/x0.pem))
  ];

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    # iwd takes full control of network configuration and
    # does not allow it to be read-only (or symlinked).
    "/var/lib/iwd"
  ];
}
