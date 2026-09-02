{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) mkHost';
  inherit (lib.modules) mkMerge;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };

  services = {
    unbound = {
      enable = true;

      package = pkgs.unbound.override {
        withSystemd = true;
        withRedis = true;
      };

      settings = {
        server = mkMerge [
          {
            interface = [
              (mkHost' sigil.self.addresses.ula 53)
            ];

            do-udp = true;
            do-tcp = true;
          }
          {
            # https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html#unbound-conf-access-control
            access-control = [
              # NOTE: Allow requests from inside the internal network (intra.net®).
              "fda0:9527:68ee::/48 allow"
            ];
          }
          {
            deny-any = true;
          }
          {
            aggressive-nsec = true;
            use-caps-for-id = true;

            hide-identity = true;
            hide-version = false;

            harden-algo-downgrade = true;
            harden-below-nxdomain = true;

            harden-large-queries = true;
            harden-referral-path = true;

            harden-dnssec-stripped = true;
            harden-unverified-glue = true;
          }
          {
            infra-host-ttl = 60;
          }
          {
            serve-expired = true;
            prefetch = true;
            prefetch-key = true;
          }
          {
            # https://nlnetlabs.nl/documentation/unbound/howto-optimise/
            num-threads = 8;

            key-cache-slabs = 8;
            infra-cache-slabs = 8;
            msg-cache-slabs = 8;
            rrset-cache-slabs = 8;

            # Due to `malloc` overhead, the total memory usage
            # is likely to rise to double (or 2.5x) the total
            # cache memory that is entered into the config.
            rrset-cache-size = "128m";
            msg-cache-size = "64m";

            outgoing-range = 64;
            num-queries-per-thread = 32;
          }
          {
            log-queries = true;
            log-replies = true;
          }
          {
            extended-statistics = true;
          }
          {
            val-clean-additional = true;
            val-permissive-mode = false;
          }
        ];

        forward-zone = [
          {
            name = ".";

            forward-tls-upstream = true;

            forward-addr = [
              "2606:4700:4700::1111#one.one.one.one"
              "2606:4700:4700::1001#one.one.one.one"
            ];
          }
        ];

        auth-zone = let
          ip = {
            dns = sigil.self.addresses.ula;
            web = sigil.containers.intra.e079b57e-4727-4408-8c33-39abaae975d9.addresses.ula;
          };
        in [
          (pkgs.custom.writeAuthZone "intra.net.internal" {
            AAAA = [ip.web];

            SOA = {
              nameServer = "aether.ns.intra.net.internal.";
              minimum = 86400;
              serial = 2026082701;
              retry = 1800;
              expire = 604800;
              refresh = 3600;
              adminEmail = "noc@aether.ns.intra.net.internal";
            };

            NS = ["aether.ns.intra.net.internal."];

            subdomains = mkMerge [
              {
                "aether.ns" = {
                  AAAA = [
                    ip.dns
                  ];
                };
              }
              {
                "directory" = {
                  AAAA = [
                    ip.web
                  ];
                };
                "forge.dev" = {
                  AAAA = [
                    ip.web
                  ];
                };
                "pocket-id" = {
                  AAAA = [
                    ip.web
                  ];
                };
              }
            ];
          })
          (pkgs.custom.writeAuthZone "hosts.net.internal" {
            SOA = {
              nameServer = "aether.ns.hosts.net.internal.";
              minimum = 86400;
              serial = 2026082701;
              retry = 1800;
              expire = 604800;
              refresh = 3600;
              adminEmail = "noc@aether.ns.hosts.net.internal";
            };

            NS = ["aether.ns.hosts.net.internal."];

            subdomains = mkMerge [
              {
                "aether.ns" = {
                  AAAA = [
                    ip.dns
                  ];
                };
              }
              {
                "aether" = {
                  AAAA = [
                    "fda0:9527:68ee:4f8a:f7f3:176c:41e0:4098"
                  ];
                };
                "albedo" = {
                  AAAA = [
                    "fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a"
                  ];
                };
                "keqing" = {
                  AAAA = [
                    "fda0:9527:68ee:4f8a:afbf:7002:aa5f:a363"
                  ];
                };
                "lumine" = {
                  AAAA = [
                    "fda0:9527:68ee:4f8a:46a1:b595:357f:c251"
                  ];
                };
              }
            ];
          })
        ];

        # Control socket is used
        # by a metrics exporter.
        remote-control = {
          control-enable = true;
          control-interface = "/var/run/unbound/unbound.sock";
        };
      };
    };

    # LOGROTATE
    # ---------
    logrotate = {
      settings = {
        "/var/log/unbound/unbound.log" = {
          daily = true;
          rotate = 7;
          missingok = true;
          compress = true;
          delaycompress = true;
          notifempty = true;
          postrotate = ''
            unbound-control log_reopen
          '';
          endscript = true;
        };
      };
    };
  };

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 4194304;
    "net.core.wmem_max" = 4194304;
  };
}
