{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) radii resolvers;
  inherit (lib.extra) ip url;
  inherit (lib.extra.sigil) getULA;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.lists) concatMap;
  inherit (lib.modules) mkMerge;
in {
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
            interface = let
              inherit (url.interface) fromParts toNLnetLabs;
            in [
              (toNLnetLabs (fromParts (sigil.self |> getULA) 53))
            ];

            do-udp = true;
            do-tcp = true;
          }
          {
            access-control = let
              sourceAddresses = import ./_facts/rules/incoming.nix {
                inherit (sigil) containers;
                inherit lib;
              };
            in
              sourceAddresses |> mapPipeline [ip.toCIDR (a: "${a} allow")];
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

            forward-addr = let
              usedResolvers = [
                # Cloudflare
                # ----------
                {
                  sniHostname = "one.one.one.one";
                  ipAddresses = resolvers.cloudflare.standard.ipv6 |> map (a: url.mkInterface a 853);
                }
              ];
            in
              usedResolvers |> concatMap (r: r.ipAddresses |> map (url.interface.toNLnetLabsTLS r.sniHostname));
          }
        ];

        auth-zone = let
          target = {
            proxy = {
              _main = sigil.containers.intra.e079b57e-4727-4408-8c33-39abaae975d9 |> getULA |> ip.toCompressed;
            };
            dns = sigil.self |> getULA |> ip.toCompressed;
          };
        in [
          (pkgs.custom.writeAuthZone "intra.net.internal" {
            AAAA = with target.proxy; [
              _main
            ];

            SOA = {
              nameServer = "beidou.ns.intra.net.internal.";
              minimum = 86400;
              serial = 2026082701;
              retry = 1800;
              expire = 604800;
              refresh = 3600;
              adminEmail = "noc@beidou.ns.intra.net.internal";
            };

            NS = ["beidou.ns.intra.net.internal."];

            subdomains = let
              AAAA = with target.proxy; [
                _main
              ];
            in
              mkMerge [
                {
                  "beidou.ns" = {
                    inherit AAAA;
                  };
                }
                {
                  "directory" = {
                    inherit AAAA;
                  };
                  "forge.dev" = {
                    inherit AAAA;
                  };
                  "ollama.ai" = {
                    inherit AAAA;
                  };
                  "pocket-id" = {
                    inherit AAAA;
                  };
                  "proxy.uni" = {
                    inherit AAAA;
                  };
                  "workflows" = {
                    inherit AAAA;
                  };
                }
                (let
                  AAAA = with target.proxy; [
                    _main
                  ];
                in {
                  "music" = {
                    inherit AAAA;
                  };
                })
              ];
          })
          (pkgs.custom.writeAuthZone "hosts.net.internal" {
            SOA = {
              nameServer = "beidou.ns.hosts.net.internal.";
              minimum = 86400;
              serial = 2026082701;
              retry = 1800;
              expire = 604800;
              refresh = 3600;
              adminEmail = "noc@beidou.ns.hosts.net.internal";
            };

            NS = ["beidou.ns.hosts.net.internal."];

            subdomains = mkMerge [
              {
                "beidou.ns" = {
                  AAAA = with target; [
                    dns
                  ];
                };
              }
              {
                "albedo" = {
                  AAAA = [
                    (radii.site.albedo.hostAddress |> ip.toCompressed)
                  ];
                };

                "beidou" = {
                  AAAA = [
                    (radii.site.beidou.hostAddress |> ip.toCompressed)
                  ];
                };

                "collei" = {
                  AAAA = [
                    (radii.site.collei.hostAddress |> ip.toCompressed)
                  ];
                };

                "fischl" = {
                  AAAA = [
                    (radii.site.fischl.hostAddress |> ip.toCompressed)
                  ];
                };

                "keqing" = {
                  AAAA = [
                    (radii.site.keqing.hostAddress |> ip.toCompressed)
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
