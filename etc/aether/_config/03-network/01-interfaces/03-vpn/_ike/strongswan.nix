# spell-checker: ignore cacerts, NXDOMAIN, daddr, dport, mobike, prfsha, saddr
# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀█ █▀█ █ █░█ ▄▀█ ▀█▀ █▀▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █▀▀ █▀▄ █ ▀▄▀ █▀█ ░█░ ██▄
#
# █▄░█ █▀▀ ▀█▀ █░█░█ █▀█ █▀█ █▄▀ █▀
# █░▀█ ██▄ ░█░ ▀▄▀▄▀ █▄█ █▀▄ █░█ ▄█
#
# TAGS: VPN, IPsec, IKEv2, StrongSwan
# DOCS: https://docs.strongswan.org
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  shared,
  lib,
  ...
}: let
  inherit (shared.virtual-private-networks.ike-ipsec) anchor mkAddr mkFQDN prefix spokes;
in {
  services.strongswan = {
    enable = true;

    settings = {
      swanctl = {
        authorities = {
          aether = {
            file = config.services.openbao-agent.strongswan.files."anchor.pem".path;
          };
        };

        secrets = {
          private.server.file = config.services.openbao-agent.strongswan.files."server.key".path;
        };

        pools = lib.genAttrs spokes (spoke: {
          addrs = "${(mkAddr spoke)}/128";
          dns = [(mkAddr anchor)];
        });

        connections = lib.genAttrs spokes (spoke: let
          authentication = let
            auth = "pubkey";
          in {
            remote.main = {
              inherit auth;

              id = mkFQDN spoke;

              cacert.file = config.services.openbao-agent.strongswan.files."anchor.pem".path;
            };

            local.main = {
              inherit auth;

              id = mkFQDN anchor;

              cert.file = config.services.openbao-agent.strongswan.files."server.pem".path;
            };
          };

          configuration = {
            children.mesh = {
              esp_proposals = ["aes256gcm16-x25519"];

              local_ts = [prefix];
            };
          };
        in {
          inherit (authentication) remote local;
          inherit (configuration) children;

          pools = [spoke];

          version = 2;

          proposals = ["aes256gcm16-prfsha256-x25519"];
        });
      };
    };
  };

  systemd.services.strongswan = {
    serviceConfig = {
      LoadCredential = [
        "anchor.pem:strongswan.anchor.pem"
        "server.pem:strongswan.server.pem"
        "server.key:strongswan.server.key"
      ];
    };
  };

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = 1;
  };

  systemd.network.networks = {
    "10-lo-strongswan" = {
      matchConfig.Name = "lo";
      address = ["${mkAddr anchor}/128"];
    };
  };
}
